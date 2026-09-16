"use strict";

/**
 * Actions du socle commun de détermination de la source d'approvisionnement.
 *
 * Le mock server route les function imports V2 vers l'entity set désigné par
 * sap:action-for (ici ZC_ResaPurReqWorklist) : les cinq actions sont donc traitées ici.
 * En réel, ces actions correspondent aux modules de création de DA / CA / commande
 * petite caisse et à l'enregistrement du choix de source (table ZTRESA_SRCSEL).
 *
 * Les paramètres d'un function import V2 arrivent en query string (c'est ainsi que
 * Fiori elements les envoie) ; le corps de la requête est utilisé en complément.
 */

const SOURCE_TYPE_TEXTS = {
    EDI: "Fournisseur EDI",
    WHSE: "Entrepôt",
    STOR: "Centre voisin",
    CASH: "Commande petite caisse"
};

// le mock server appelle soit (def, data, keys, request) soit (def, data, request, keys)
function pickRequest(argA, argB) {
    if (argA && (argA.allParams || argA.queryPath)) {
        return argA;
    }
    if (argB && (argB.allParams || argB.queryPath)) {
        return argB;
    }
    return {};
}

// '0010010012' / datetime'2026-10-01T00:00:00' / 4.000m -> valeur exploitable
function decodeLiteral(rawValue) {
    let value = String(rawValue);
    try {
        value = decodeURIComponent(value);
    } catch (e) {
        // valeur déjà décodée
    }
    const typed = /^(?:datetime|datetimeoffset|guid|time)'(.*)'$/i.exec(value);
    if (typed) {
        return typed[1];
    }
    const quoted = /^'(.*)'$/.exec(value);
    if (quoted) {
        return quoted[1].replace(/''/g, "'");
    }
    const numeric = /^([-+]?\d+(?:\.\d+)?)[mMdDfFlL]?$/.exec(value);
    if (numeric) {
        return numeric[1];
    }
    return value;
}

function mergeParameters(actionData, odataRequest) {
    const parameters = actionData && typeof actionData === "object" ? Object.assign({}, actionData) : {};
    const allParams = odataRequest && odataRequest.allParams;
    if (allParams && typeof allParams.forEach === "function") {
        allParams.forEach(function (value, key) {
            if (key.charAt(0) !== "$" && key.indexOf("sap-") !== 0 && key !== "logs") {
                parameters[key] = decodeLiteral(value);
            }
        });
    }
    return parameters;
}

module.exports = {
    async executeAction(actionDefinition, actionData, argA, argB) {
        const odataRequest = pickRequest(argA, argB);
        const parameters = mergeParameters(actionData, odataRequest);
        const action = actionDefinition.name;
        const worklist = await this.base.getAllEntries(odataRequest);
        const itemKeys = {
            PurchaseRequisition: parameters.PurchaseRequisition,
            PurchaseRequisitionItem: parameters.PurchaseRequisitionItem
        };
        const findItem = () =>
            worklist.find(
                (line) =>
                    line.PurchaseRequisition === parameters.PurchaseRequisition &&
                    line.PurchaseRequisitionItem === parameters.PurchaseRequisitionItem
            );

        // ---------------------------------------------------------- retenir une source
        if (action === "AssignSource") {
            const options = await this.base.getEntityInterface("ZC_ResaSourceOption");
            const allOptions = await options.getAllEntries(odataRequest);
            const option = allOptions.find((line) => line.SourceOptionId === parameters.SourceOptionId);
            if (!option) {
                this.throwError(`Option de source inconnue : ${parameters.SourceOptionId}`, 400);
            }
            const item = findItem();
            if (!item) {
                this.throwError("Poste de demande d'achat inconnu", 400);
            }
            // une seule source retenue par poste
            for (const line of allOptions) {
                if (
                    line.PurchaseRequisition === option.PurchaseRequisition &&
                    line.PurchaseRequisitionItem === option.PurchaseRequisitionItem &&
                    line.IsSelected === "X"
                ) {
                    await options.updateEntry({ SourceOptionId: line.SourceOptionId }, { IsSelected: "" }, odataRequest);
                }
            }
            await options.updateEntry({ SourceOptionId: option.SourceOptionId }, { IsSelected: "X" }, odataRequest);

            const patch = {
                SelectedSourceType: option.SourceType,
                SelectedSourceTypeText: option.SourceTypeText,
                SelectedSourceId: option.SourceId,
                SelectedSourceName: option.SourceName,
                SourceStatus: "SEL",
                SourceStatusText: "Source choisie",
                SourceCriticality: 2
            };
            await this.base.updateEntry(itemKeys, patch, odataRequest);
            return Object.assign({}, item, patch);
        }

        // ------------------------------------------- convertir en commande d'achat
        if (action === "ConvertToPurchaseOrder") {
            const item = findItem();
            if (!item) {
                this.throwError("Poste de demande d'achat inconnu", 400);
            }
            if (item.SourceStatus === "CONV") {
                this.throwError("Ce poste est déjà approvisionné", 400);
            }
            if (!item.SelectedSourceType && !parameters.SourceOptionId) {
                this.throwError("Retenir d'abord une source d'approvisionnement", 400);
            }
            const purchaseOrder = String(4500090000 + worklist.length + 1);
            const patch = {
                PurchaseOrder: purchaseOrder,
                FollowOnDocument: purchaseOrder,
                FollowOnDocumentType: "ZDI5",
                ChainStage: "PO",
                ChainStageText: "Commande d'achat créée",
                SourceStatus: "CONV",
                SourceStatusText: "Approvisionnement lancé",
                SourceCriticality: 3
            };
            await this.base.updateEntry(itemKeys, patch, odataRequest);
            return Object.assign({}, item, patch);
        }

        // ------------------------------------------- commande petite caisse
        if (action === "CreatePettyCashOrder") {
            const item = findItem();
            if (!item) {
                this.throwError("Poste de demande d'achat inconnu", 400);
            }
            if (item.SourceStatus === "CONV") {
                this.throwError("Ce poste est déjà approvisionné", 400);
            }
            const pettyCashSet = await this.base.getEntityInterface("ZC_ResaPettyCashOrder");
            const existing = await pettyCashSet.getAllEntries(odataRequest);
            const pettyCashOrder = String(9100000200 + existing.length + 1);
            await pettyCashSet.addEntry(
                {
                    PettyCashOrder: pettyCashOrder,
                    Reservation: item.Reservation,
                    PurchaseRequisition: item.PurchaseRequisition,
                    PurchaseRequisitionItem: item.PurchaseRequisitionItem,
                    Plant: item.Plant,
                    Material: item.Material,
                    ItemText: item.PurchaseRequisitionItemText,
                    Quantity: item.RequestedQuantity,
                    BaseUnit: item.BaseUnit,
                    Amount:
                        parameters.Amount !== undefined && parameters.Amount !== null && parameters.Amount !== ""
                            ? String(parameters.Amount)
                            : item.ItemAmount,
                    Currency: item.Currency,
                    LocalSupplierName: parameters.LocalSupplierName || "Achat local",
                    CreationDate: item.PurReqDate,
                    CreatedByUser: "MAGASIN01",
                    PettyCashStatus: "CR",
                    PettyCashStatusText: "Créée"
                },
                odataRequest
            );
            await this.base.updateEntry(
                itemKeys,
                {
                    FollowOnDocument: pettyCashOrder,
                    FollowOnDocumentType: "ZPC",
                    ChainStage: "PC",
                    ChainStageText: "Commande petite caisse",
                    SelectedSourceType: "CASH",
                    SelectedSourceTypeText: SOURCE_TYPE_TEXTS.CASH,
                    SelectedSourceId: "PETITECAISSE",
                    SelectedSourceName: "Achat local - petite caisse",
                    SourceStatus: "CONV",
                    SourceStatusText: "Approvisionnement lancé",
                    SourceCriticality: 3
                },
                odataRequest
            );
            return (await pettyCashSet.getAllEntries(odataRequest)).find((line) => line.PettyCashOrder === pettyCashOrder);
        }

        // ------------------------------------------- créations de besoin
        if (action === "CreatePurchaseRequisition" || action === "CreateReplenishmentOrder") {
            const replenishment = action === "CreateReplenishmentOrder";
            const sequence = worklist.length + 1;
            const purchaseRequisition = String(10019000 + sequence).padStart(10, "0");
            const quantity = Number(parameters.Quantity || 1);
            const unitPrice = 24.5;
            const purchaseOrder = replenishment ? String(4500095000 + sequence) : "";
            const requestedDate = parameters.RequestedDate
                ? String(parameters.RequestedDate).slice(0, 10)
                : new Date().toISOString().slice(0, 10);
            const newItem = {
                PurchaseRequisition: purchaseRequisition,
                PurchaseRequisitionItem: "00010",
                Reservation: "",
                OriginType: "AUTR",
                OriginTypeText: "Réapprovisionnement manuel",
                Plant: parameters.Plant || "1000",
                PurchasingGroup: "001",
                Material: parameters.Material || "",
                PurchaseRequisitionItemText: parameters.ItemText || "",
                PurReqDate: requestedDate,
                RequestedQuantity: quantity.toFixed(3),
                BaseUnit: "PC",
                ItemAmount: (quantity * unitPrice).toFixed(3),
                Currency: "EUR",
                PurchaseOrder: purchaseOrder,
                FollowOnDocument: purchaseOrder,
                FollowOnDocumentType: replenishment ? "ZDI5" : "",
                ChainStage: replenishment ? "PO" : "PR",
                ChainStageText: replenishment ? "Commande d'achat créée" : "Demande d'achat en attente",
                SourceOptionCount: 0,
                SupplierSourceCount: 0,
                PettyCashEligible: false,
                SelectedSourceType: replenishment ? parameters.SourceType || "EDI" : "",
                SelectedSourceTypeText: replenishment ? SOURCE_TYPE_TEXTS[parameters.SourceType || "EDI"] : "",
                SelectedSourceId: replenishment ? parameters.SourceId || "" : "",
                SelectedSourceName: replenishment ? parameters.SourceId || "" : "",
                SourceStatus: replenishment ? "CONV" : "TODO",
                SourceStatusText: replenishment ? "Approvisionnement lancé" : "À traiter",
                SourceCriticality: replenishment ? 3 : 1
            };
            await this.base.addEntry(newItem, odataRequest);
            return newItem;
        }

        this.throwError(`Action non gérée par la maquette : ${action}`, 501);
    }
};
