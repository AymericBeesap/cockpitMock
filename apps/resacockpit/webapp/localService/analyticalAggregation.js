"use strict";

/**
 * Simule côté mock server l'agrégation d'une requête analytique OData V2
 * (@Analytics.query / sap:semantics="aggregate").
 *
 * Le serveur ABAP agrège selon les dimensions présentes dans $select ; le mock server
 * renvoie les lignes brutes. Ce hook onAfterRead regroupe les lignes déjà filtrées par
 * les dimensions sélectionnées, somme les mesures et recalcule les formules
 * (@AnalyticsDetails.query.formula) à partir des mesures agrégées.
 *
 * Le mock server applique $skip / $top avant onAfterRead : les en-têtes KPI des cartes
 * (requêtes $top=1) ne verraient qu'une ligne brute. getAllEntries, appelé avant la
 * pagination, la neutralise et onAfterRead la réapplique après agrégation.
 */

const PAGING = Symbol("aggregationPaging");

const KEY_IN_URI = /\('([^']*)'\)\s*$/;

function idFromMetadata(metadata) {
    const match = metadata && KEY_IN_URI.exec(decodeURIComponent(metadata.uri || ""));
    return match ? match[1] : undefined;
}

function compareValues(a, b) {
    if (a === b) {
        return 0;
    }
    if (a === undefined || a === null) {
        return -1;
    }
    if (b === undefined || b === null) {
        return 1;
    }
    const numA = Number(a);
    const numB = Number(b);
    if (!Number.isNaN(numA) && !Number.isNaN(numB)) {
        return numA - numB;
    }
    return String(a).localeCompare(String(b));
}

/**
 * @param {object} config
 * @param {string[]} config.dimensions propriétés de regroupement (dimensions et leurs textes)
 * @param {string[]} config.measures mesures sommées (@DefaultAggregation: #SUM)
 * @param {Object<string, function(object): (number|string)>} [config.formulas] mesures calculées à partir des sommes
 * @param {Object<string, number>} [config.scales] nombre de décimales des mesures Edm.Decimal
 * @returns {{getAllEntries: function, onAfterRead: function}} hooks du mock server
 */
module.exports = function createAggregationHooks({ dimensions, measures, formulas = {}, scales = {} }) {
    async function getAllEntries(odataRequest, dontClone) {
        if (odataRequest && !odataRequest[PAGING]) {
            odataRequest[PAGING] = { start: odataRequest.startIndex || 0, max: odataRequest.maxElements };
            odataRequest.startIndex = 0;
            odataRequest.maxElements = Number.POSITIVE_INFINITY;
        }
        return this.base.getAllEntries(odataRequest, dontClone);
    }

    async function onAfterRead(data, odataRequest) {
        if (!Array.isArray(data) || data.length === 0) {
            return data;
        }

        // $select a déjà retiré les mesures non demandées : les formules ont besoin des lignes complètes
        const allEntries = await this.base.getAllEntries(odataRequest);
        const fullRowById = new Map(allEntries.map((entry) => [entry.ID, entry]));

        const selected = Object.keys(data[0]).filter((property) => property !== "__metadata");
        if (process.env.MOCK_AGG_DEBUG) {
            console.log(`[aggregation] ${data.length} lignes, propriétés reçues : ${selected.join(",")}`);
        }
        const groupProperties = selected.filter((property) => dimensions.includes(property));
        const measureProperties = selected.filter((property) => measures.includes(property) || property in formulas);

        const groups = new Map();
        for (const row of data) {
            const fullRow = fullRowById.get(idFromMetadata(row.__metadata)) || row;
            const groupKey = JSON.stringify(groupProperties.map((property) => fullRow[property]));
            let group = groups.get(groupKey);
            if (!group) {
                group = {
                    sample: fullRow,
                    metadata: row.__metadata,
                    sums: Object.fromEntries(measures.map((measure) => [measure, 0]))
                };
                groups.set(groupKey, group);
            }
            measures.forEach((measure) => {
                group.sums[measure] += Number(fullRow[measure]) || 0;
            });
        }

        const result = [...groups.values()].map((group) => {
            const id =
                groupProperties.map((property) => String(group.sample[property]).replace(/[^\w]/g, "")).join("_") || "TOTAL";
            const line = {};
            if (group.metadata) {
                line.__metadata = Object.assign({}, group.metadata, {
                    id: String(group.metadata.id || "").replace(KEY_IN_URI, `('${id}')`),
                    uri: String(group.metadata.uri || "").replace(KEY_IN_URI, `('${id}')`)
                });
            }
            if (selected.includes("ID")) {
                line.ID = id;
            }
            groupProperties.forEach((property) => {
                line[property] = group.sample[property];
            });
            measureProperties.forEach((property) => {
                const value = property in formulas ? formulas[property](group.sums) : group.sums[property];
                line[property] = property in scales ? Number(value).toFixed(scales[property]) : value;
            });
            return line;
        });

        // le tri demandé peut porter sur une mesure : il doit être réappliqué après agrégation
        const orderBy = odataRequest.orderBy || [];
        if (orderBy.length > 0) {
            result.sort((lineA, lineB) => {
                for (const { name, direction } of orderBy) {
                    const comparison = compareValues(lineA[name], lineB[name]);
                    if (comparison !== 0) {
                        return direction === "desc" ? -comparison : comparison;
                    }
                }
                return 0;
            });
        }

        const paging = odataRequest[PAGING];
        // comme le mock server : $top=0 (requête de comptage) ne pagine pas
        if (paging && paging.max) {
            const end = Number.isFinite(paging.max) ? paging.start + paging.max : undefined;
            return result.slice(paging.start, end);
        }
        return result;
    }

    return { getAllEntries, onAfterRead };
};
