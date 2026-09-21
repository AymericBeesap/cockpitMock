"use strict";

/**
 * Action SelectSource du service mocké ZUI_RESASRC (OData V4).
 *
 * Reproduit en local ce que fait le business object RAP :
 *   - la source retenue est relue dans SourceOption (comme ZCL_RESA_SRC_PROVIDER~get_source) ;
 *   - l'affectation à la demande d'achat est simulée (comme BAPI_PR_CHANGE) ;
 *   - le refus du standard sur une source « centre voisin » ou « entrepôt » est reproduit :
 *     statut ERR et message, exactement le point dur du relevé R4.
 *
 * Écart local assumé : en réel, un poste dont l'affectation réussit quitte la liste de travail,
 * puisque la demande d'achat porte désormais une source. Le mock server ne supprime pas la ligne
 * pour que Fiori elements puisse rafraîchir l'instance retournée par l'action : le poste reste
 * donc visible avec le statut « Source retenue ».
 */

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

function pickKeys(argA, argB) {
    const isKeys = (value) => value && typeof value === "object" && !value.allParams && !value.queryPath;
    if (isKeys(argA)) {
        return argA;
    }
    if (isKeys(argB)) {
        return argB;
    }
    return {};
}

module.exports = {
    async executeAction(actionDefinition, actionData, argA, argB) {
        const odataRequest = pickRequest(argA, argB);
        const keys = pickKeys(argA, argB);
        const parameters = Object.assign({}, actionData || {});

        if (actionDefinition.name !== "SelectSource") {
            this.throwError(`Action non gérée par la maquette : ${actionDefinition.name}`, 501);
        }

        const items = await this.base.getAllEntries(odataRequest);
        const purchaseRequisition = keys.PurchaseRequisition || parameters.PurchaseRequisition;
        const purchaseRequisitionItem = keys.PurchaseRequisitionItem || parameters.PurchaseRequisitionItem;

        const item = items.find(
            (line) =>
                line.PurchaseRequisition === purchaseRequisition &&
                line.PurchaseRequisitionItem === purchaseRequisitionItem
        );
        if (!item) {
            this.throwError("Poste de demande d'achat inconnu", 400);
        }

        // message ZRESA_SRC 005 : une source doit être retenue
        if (!parameters.SourceId) {
            this.throwError("Retenir une source d'approvisionnement", 400);
        }

        // message ZRESA_SRC 001 : la source doit toujours exister au moment de la validation
        const optionSet = await this.base.getEntityInterface("SourceOption");
        const allOptions = await optionSet.getAllEntries(odataRequest);
        const option = allOptions.find(
            (line) =>
                line.PurchaseRequisition === purchaseRequisition &&
                line.PurchaseRequisitionItem === purchaseRequisitionItem &&
                line.SourceId === parameters.SourceId &&
                (!parameters.SourceType || line.SourceType === parameters.SourceType)
        );
        if (!option) {
            this.throwError(`Source inconnue pour ce poste : ${parameters.SourceType || ""} ${parameters.SourceId}`, 400);
        }

        // Point dur du relevé R4 : sur un poste de catégorie standard, le standard refuse de
        // porter une division livreuse. Le refus est tracé, le poste reste à traiter.
        const refused = option.SourceType === "STOR" || option.SourceType === "WHSE";

        const patch = {
            SelectedSourceType: option.SourceType,
            SelectedSourceId: option.SourceId,
            SelectedSourceName: option.SourceName,
            SelectedNetPrice: option.NetPrice,
            SelectedLeadTimeDays: option.LeadTimeDays,
            SelectionStatus: refused ? "ERR" : "SEL",
            SelectionStatusText: refused ? "Affectation refusée par la demande d'achat" : "Source retenue",
            SelectionCriticality: refused ? 1 : 2,
            SelectionMessage: refused
                ? `Poste ${purchaseRequisitionItem} : modification de la division livreuse impossible, catégorie de poste incompatible`
                : "",
            LastChangedBy: "ACHAT01",
            LastChangedAt: new Date().toISOString().replace(/\.\d+Z$/, "Z"),
            CreatedBy: item.CreatedBy || "ACHAT01",
            CreatedAt: item.CreatedAt || new Date().toISOString().replace(/\.\d+Z$/, "Z")
        };

        await this.base.updateEntry(
            {
                PurchaseRequisition: purchaseRequisition,
                PurchaseRequisitionItem: purchaseRequisitionItem
            },
            patch,
            odataRequest
        );

        return Object.assign({}, item, patch);
    }
};
