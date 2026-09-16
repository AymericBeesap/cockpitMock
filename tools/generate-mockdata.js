"use strict";
// Génère les données de démonstration cohérentes des services mockés.
// Usage : node tools/generate-mockdata.js
const fs = require("fs");
const path = require("path");

const appsDir = path.join(__dirname, "..", "apps");
const DAY = 24 * 3600 * 1000;
const START = Date.UTC(2026, 5, 1); // 01/06/2026

const odataDate = (ms) => `/Date(${ms})/`;
const ymd = (ms) => new Date(ms).toISOString().slice(0, 10).replace(/-/g, "");
const write = (relativeFile, data) => {
    const file = path.join(appsDir, relativeFile);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(data, null, 4) + "\n", "utf8");
    console.log(`${relativeFile}: ${data.length} lignes`);
};

// ---------------------------------------------------------------- chaîne DA
const plants = ["1000", "1100", "1200"];
const groups = ["001", "002"];
const materials = [
    ["MAT-10045", "Étagère métal 180 cm"],
    ["MAT-20310", "Présentoir caisse"],
    ["MAT-31002", "Rouleau étiquettes prix"],
    ["MAT-40077", "Bac de rangement 40 L"],
    ["MAT-52210", "Lampe LED vitrine"],
    ["MAT-60981", "Panneau signalétique"]
];
const originTexts = { RESA: "Réservation magasin", VENT: "Commande client", AUTR: "Autre" };
const stageTexts = {
    PO: "Commande d'achat créée",
    PC: "Commande petite caisse",
    PR: "Demande d'achat en attente"
};

// postes soldés par une commande petite caisse déjà passée (achat local de dernier recours)
const PETTY_CASH_ITEMS = [25, 31];

const tracking = [];
for (let i = 0; i < 36; i++) {
    const originType = i % 6 < 4 ? "RESA" : i % 6 === 4 ? "VENT" : "AUTR";
    // les postes anciens sont majoritairement convertis, les récents restent en attente
    const converted = i < 24 ? i % 5 !== 2 : i % 3 === 0;
    const pettyCash = !converted && PETTY_CASH_ITEMS.includes(i);
    const [material, text] = materials[i % materials.length];
    const date = START + i * 2 * DAY;
    const quantity = 2 + ((i * 7) % 20);
    const price = [45.5, 129.9, 12.4, 18.75, 64.0, 32.2][i % 6];
    const purchaseOrder = converted ? String(4500012000 + i) : "";
    const pettyCashOrder = pettyCash ? String(9100000100 + i) : "";
    const stage = converted ? "PO" : pettyCash ? "PC" : "PR";

    tracking.push({
        PurchaseRequisition: String(10010001 + Math.floor(i / 2)).padStart(10, "0"),
        PurchaseRequisitionItem: String((i % 2) * 10 + 10).padStart(5, "0"),
        Reservation: originType === "RESA" ? `RES${String(260001 + i).padStart(7, "0")}` : "",
        SalesOrder: originType === "VENT" ? String(30004500 + i).padStart(10, "0") : "",
        SalesOrderItem: originType === "VENT" ? "000010" : "",
        SalesOrderItemText: originType === "VENT" ? text : "",
        PurchaseOrder: purchaseOrder,
        PurchaseOrderItem: converted ? "00010" : "",
        PurchaseOrderItemText: converted ? text : "",
        FollowOnDocument: purchaseOrder || pettyCashOrder,
        FollowOnDocumentType: converted ? "ZDI5" : pettyCash ? "ZPC" : "",
        OriginType: originType,
        OriginTypeText: originTexts[originType],
        ChainStage: stage,
        ChainStageText: stageTexts[stage],
        ChainCriticality: converted || pettyCash ? 3 : 2,
        Plant: plants[i % 3],
        PurchasingGroup: groups[i % 2],
        Material: material,
        PurchaseRequisitionItemText: text,
        PurReqDate: odataDate(date),
        RequestedQuantity: quantity.toFixed(3),
        BaseUnit: "PC",
        ItemAmount: (quantity * price).toFixed(3),
        Currency: "EUR",
        _index: i,
        _date: date,
        _pettyCash: pettyCash
    });
}

// requête de la chaîne : grain le plus fin (le hook du mock server agrège)
const chainRows = new Map();
for (const item of tracking) {
    const id = [item.Plant, item.PurchasingGroup, item.OriginType, item.ChainStage, ymd(item._date)].join("_");
    const row = chainRows.get(id) || {
        ID: id,
        Plant: item.Plant,
        PurchasingGroup: item.PurchasingGroup,
        OriginType: item.OriginType,
        OriginTypeText: item.OriginTypeText,
        ChainStage: item.ChainStage,
        ChainStageText: item.ChainStageText,
        PurReqDate: item.PurReqDate,
        PurReqItemCount: 0,
        ConvertedItemCount: 0,
        OpenItemCount: 0,
        ItemAmount: 0,
        Currency: item.Currency
    };
    row.PurReqItemCount += 1;
    row.ConvertedItemCount += item.ChainStage === "PO" ? 1 : 0;
    // un poste soldé en petite caisse n'est plus en attente
    row.OpenItemCount += item.ChainStage === "PR" ? 1 : 0;
    row.ItemAmount += Number(item.ItemAmount);
    chainRows.set(id, row);
}
const chainQuery = [...chainRows.values()].map((row) => ({
    ...row,
    ItemAmount: row.ItemAmount.toFixed(3),
    ConversionRate: ((row.ConvertedItemCount / row.PurReqItemCount) * 100).toFixed(1)
}));

// ---------------------------------------------------------------- IDocs
const stores = ["MAG0101", "MAG0102", "MAG0205", "MAG0310"];
// statuts par IDoc : majoritairement intégrés, erreurs concentrées sur deux magasins
const statuses = [
    "53", "53", "51", "53", "62", "53", "56", "53", "53", "51",
    "53", "68", "53", "51", "53", "64", "53", "53", "63", "53",
    "51", "53", "62", "53", "61", "53", "53", "51", "53", "53"
];
const statusTexts = {
    "51": "Document d'application non enregistré",
    "53": "Document d'application enregistré",
    "56": "IDoc avec erreurs ajouté",
    "61": "Traitement malgré erreur de syntaxe",
    "62": "IDoc transmis à l'application",
    "63": "Erreur lors de la transmission de l'IDoc à l'application",
    "64": "IDoc prêt pour transmission à l'application",
    "68": "Erreur - pas de traitement ultérieur"
};
const errorMessages = [
    ["ME", "083", "Article MAT-31002 non géré dans la division 1100"],
    ["06", "280", "Groupe d'acheteurs 003 non défini pour l'organisation d'achats"],
    ["ZRESA", "012", "Réservation déjà intégrée : doublon rejeté"],
    ["E0", "414", "Partenaire émetteur non paramétré pour le type de message Z_CREA_PR"]
];
// regroupement et criticité identiques à ZI_ResaIdocMonitor
const integration = (status) =>
    ["53", "62"].includes(status) ? "OK" : ["51", "56", "61", "63"].includes(status) ? "KO" : status === "68" ? "AB" : "EC";
const criticality = { OK: 3, KO: 1, AB: 0, EC: 2 };

const idocs = statuses.map((status, i) => {
    const integrationStatus = integration(status);
    const store = ["51", "56"].includes(status) ? stores[i % 2 === 0 ? 1 : 3] : stores[i % 4];
    const date = START + ((i * 5) % 60) * DAY;
    const [messageClass, messageNumber, errorText] =
        integrationStatus === "KO" ? errorMessages[i % errorMessages.length] : ["", "", ""];
    let messageText = errorText;
    if (integrationStatus === "OK") {
        messageText = `Demande d'achat ${String(10010001 + i).padStart(10, "0")} créée`;
    } else if (integrationStatus === "AB") {
        messageText = "Traitement arrêté manuellement";
    } else if (integrationStatus === "EC") {
        messageText = "En attente de traitement par le module d'entrée";
    }
    return {
        IDocNumber: String(4512000 + i).padStart(16, "0"),
        MessageType: "Z_CREA_PR",
        IDocType: "ZCREA_PR01",
        SenderPartner: store,
        CreationDate: odataDate(date),
        CreationTime: `PT${String(7 + (i % 11)).padStart(2, "0")}H${String((i * 13) % 60).padStart(2, "0")}M00S`,
        IDocStatus: status,
        IDocStatusText: statusTexts[status],
        IntegrationStatus: integrationStatus,
        StatusCriticality: criticality[integrationStatus],
        MessageClass: messageClass,
        MessageNumber: messageNumber,
        MessageText: messageText,
        _date: date
    };
});

const idocRows = new Map();
for (const idoc of idocs) {
    const id = [idoc.SenderPartner, idoc.IntegrationStatus, ymd(idoc._date)].join("_");
    const row = idocRows.get(id) || {
        ID: id,
        SenderPartner: idoc.SenderPartner,
        IntegrationStatus: idoc.IntegrationStatus,
        CreationDate: idoc.CreationDate,
        IDocCount: 0,
        IDocErrorCount: 0
    };
    row.IDocCount += 1;
    row.IDocErrorCount += idoc.IntegrationStatus === "KO" ? 1 : 0;
    idocRows.set(id, row);
}
const idocQuery = [...idocRows.values()].map((row) => ({
    ...row,
    IntegrationRate: (((row.IDocCount - row.IDocErrorCount) / row.IDocCount) * 100).toFixed(1)
}));

// ---------------------------------------------------------------- sources d'approvisionnement
const ediSuppliers = [
    ["0000501234", "CENTRALE NATIONALE FOURNITURES", 2],
    ["0000502781", "NVC DISTRIBUTION", 3],
    ["0000503920", "EQUIPEMENT MAGASIN SAS", 5]
];
const warehouses = [["WH001", "Entrepôt central Nord", 1], ["WH002", "Entrepôt Sud", 2]];
const neighbours = {
    "1000": [["1100", "Centre Lyon Part-Dieu", 1], ["1200", "Centre Grenoble", 2]],
    "1100": [["1000", "Centre Lyon Confluence", 1]],
    "1200": [["1100", "Centre Lyon Part-Dieu", 2], ["1000", "Centre Lyon Confluence", 3]]
};
const sourceTypeTexts = {
    EDI: "Fournisseur EDI",
    WHSE: "Entrepôt",
    STOR: "Centre voisin",
    CASH: "Commande petite caisse"
};
const availabilityTexts = { A: "Disponible", B: "Partiellement disponible", C: "Non disponible" };
const availabilityCriticality = { A: 3, B: 2, C: 1 };
const PETTY_CASH_LIMIT = 200;
// postes volontairement sans aucune source fournisseur : seule la petite caisse reste possible
// (indices choisis parmi les postes encore en attente, cf. la règle « converted » ci-dessus)
const NO_SUPPLIER_ITEMS = [7, 22, 29];

const sourceOptions = [];
const addOption = (item, sourceType, sourceId, sourceName, availability, availableQty, leadTime, price) => {
    sourceOptions.push({
        SourceOptionId: `${item.PurchaseRequisition}_${item.PurchaseRequisitionItem}_${sourceType}_${sourceId}`,
        PurchaseRequisition: item.PurchaseRequisition,
        PurchaseRequisitionItem: item.PurchaseRequisitionItem,
        SourceType: sourceType,
        SourceTypeText: sourceTypeTexts[sourceType],
        SourceId: sourceId,
        SourceName: sourceName,
        Availability: availability,
        AvailabilityText: availabilityTexts[availability],
        SourceCriticality: availabilityCriticality[availability],
        AvailableQuantity: availableQty.toFixed(3),
        BaseUnit: item.BaseUnit,
        LeadTimeDays: leadTime,
        NetPrice: price.toFixed(2),
        Currency: item.Currency,
        IsSelected: ""
    });
};

const worklist = tracking.map((item) => {
    const i = item._index;
    const quantity = Number(item.RequestedQuantity);
    const unitPrice = Number(item.ItemAmount) / quantity;
    const open = item.ChainStage === "PR";
    const noSupplier = NO_SUPPLIER_ITEMS.includes(i);
    const before = sourceOptions.length;

    if (open) {
        if (!noSupplier) {
            // fournisseurs EDI : disponibilité issue du contrôle ZC10 en réel
            if (i % 4 !== 3) {
                const [supplierId, supplierName, leadTime] = ediSuppliers[i % ediSuppliers.length];
                addOption(item, "EDI", supplierId, supplierName, i % 3 === 2 ? "B" : "A", quantity, leadTime, unitPrice);
            }
            if (i % 5 === 0) {
                const [supplierId, supplierName, leadTime] = ediSuppliers[(i + 1) % ediSuppliers.length];
                addOption(item, "EDI", supplierId, supplierName, "A", quantity, leadTime, unitPrice * 1.08);
            }
            // entrepôt
            if (i % 3 !== 1) {
                const [whId, whName, leadTime] = warehouses[i % warehouses.length];
                const stock = i % 3 === 0 ? quantity + 12 : Math.max(1, Math.floor(quantity / 2));
                addOption(item, "WHSE", whId, whName, stock >= quantity ? "A" : "B", stock, leadTime, 0);
            }
            // centres voisins : stock disponible à la vente
            if (i % 2 === 0) {
                for (const [plantId, plantName, leadTime] of neighbours[item.Plant]) {
                    const stock = i % 4 === 0 ? quantity + 3 : Math.max(0, quantity - 4);
                    addOption(item, "STOR", plantId, plantName, stock >= quantity ? "A" : "C", stock, leadTime, 0);
                }
            }
        }
        // petite caisse : dernier recours, sous plafond — toujours offerte si aucune autre source
        if (noSupplier || Number(item.ItemAmount) <= PETTY_CASH_LIMIT) {
            addOption(item, "CASH", "PETITECAISSE", "Achat local - petite caisse", "A", quantity, 0, Number(item.ItemAmount));
        }
    }

    const options = sourceOptions.slice(before);
    const supplierCount = options.filter((option) => option.SourceType === "EDI").length;
    const converted = item.ChainStage !== "PR";
    // quelques postes ont déjà une source retenue mais pas encore d'approvisionnement lancé
    const preselected = open && !noSupplier && i % 7 === 1 && options.length > 0 ? options[0] : undefined;
    if (preselected) {
        preselected.IsSelected = "X";
    }
    const sourceStatus = converted ? "CONV" : preselected ? "SEL" : "TODO";

    return {
        PurchaseRequisition: item.PurchaseRequisition,
        PurchaseRequisitionItem: item.PurchaseRequisitionItem,
        Reservation: item.Reservation,
        OriginType: item.OriginType,
        OriginTypeText: item.OriginTypeText,
        Plant: item.Plant,
        PurchasingGroup: item.PurchasingGroup,
        Material: item.Material,
        PurchaseRequisitionItemText: item.PurchaseRequisitionItemText,
        PurReqDate: item.PurReqDate,
        RequestedQuantity: item.RequestedQuantity,
        BaseUnit: item.BaseUnit,
        ItemAmount: item.ItemAmount,
        Currency: item.Currency,
        PurchaseOrder: item.PurchaseOrder,
        FollowOnDocument: item.FollowOnDocument,
        FollowOnDocumentType: item.FollowOnDocumentType,
        ChainStage: item.ChainStage,
        ChainStageText: item.ChainStageText,
        SourceOptionCount: options.length,
        SupplierSourceCount: supplierCount,
        PettyCashEligible: options.some((option) => option.SourceType === "CASH"),
        SelectedSourceType: preselected ? preselected.SourceType : converted ? "EDI" : "",
        SelectedSourceTypeText: preselected
            ? preselected.SourceTypeText
            : converted
              ? sourceTypeTexts.EDI
              : "",
        SelectedSourceId: preselected ? preselected.SourceId : converted ? ediSuppliers[0][0] : "",
        SelectedSourceName: preselected ? preselected.SourceName : converted ? ediSuppliers[0][1] : "",
        SourceStatus: sourceStatus,
        SourceStatusText:
            sourceStatus === "CONV" ? "Approvisionnement lancé" : sourceStatus === "SEL" ? "Source choisie" : "À traiter",
        SourceCriticality: sourceStatus === "CONV" ? 3 : sourceStatus === "SEL" ? 2 : 1
    };
});

// ---------------------------------------------------------------- commandes petite caisse
const localSuppliers = ["QUINCAILLERIE DU CENTRE", "BRICO EXPRESS", "PAPETERIE LOCALE"];
const pettyCashOrders = tracking
    .filter((item) => item._pettyCash)
    .map((item, index) => ({
        PettyCashOrder: item.FollowOnDocument,
        Reservation: item.Reservation,
        PurchaseRequisition: item.PurchaseRequisition,
        PurchaseRequisitionItem: item.PurchaseRequisitionItem,
        Plant: item.Plant,
        Material: item.Material,
        ItemText: item.PurchaseRequisitionItemText,
        Quantity: item.RequestedQuantity,
        BaseUnit: item.BaseUnit,
        Amount: item.ItemAmount,
        Currency: item.Currency,
        LocalSupplierName: localSuppliers[index % localSuppliers.length],
        CreationDate: item.PurReqDate,
        CreatedByUser: "MAGASIN01",
        PettyCashStatus: index === 0 ? "JU" : "CR",
        PettyCashStatusText: index === 0 ? "Justificatif reçu" : "Créée"
    }));

// ---------------------------------------------------------------- écriture
const strip = (line) => {
    const copy = { ...line };
    delete copy._date;
    delete copy._index;
    delete copy._pettyCash;
    return copy;
};
write("resatracking/webapp/localService/ZCRESATRACK_CDS/data/ZC_ResaChainTracking.json", tracking.map(strip));
write("resacockpit/webapp/localService/ZCRESAKPI_CDS/data/ZC_ResaChainQuery.json", chainQuery);
write("resacockpit/webapp/localService/ZCRESAIDKPI_CDS/data/ZC_ResaIdocQuery.json", idocQuery);
write("resaidoc/webapp/localService/ZCRESAIDTRACK_CDS/data/ZC_ResaIdocTracking.json", idocs.map(strip));
write("alt1source/webapp/localService/ZCRESASRC_CDS/data/ZC_ResaPurReqWorklist.json", worklist);
write("alt1source/webapp/localService/ZCRESASRC_CDS/data/ZC_ResaSourceOption.json", sourceOptions);
write("alt1source/webapp/localService/ZCRESASRC_CDS/data/ZC_ResaPettyCashOrder.json", pettyCashOrders);

const open = tracking.filter((item) => item.ChainStage === "PR").length;
const resa = tracking.filter((item) => item.OriginType === "RESA");
const resaConverted = resa.filter((item) => item.ChainStage === "PO").length;
const noSource = worklist.filter((line) => line.ChainStage === "PR" && line.SupplierSourceCount === 0);
console.log(`Postes : ${tracking.length}, en attente : ${open}, petite caisse : ${pettyCashOrders.length}, conversion RESA : ${((resaConverted / resa.length) * 100).toFixed(1)} %`);
console.log(`IDocs : ${idocs.length}, en erreur : ${idocs.filter((idoc) => idoc.IntegrationStatus === "KO").length}`);
console.log(`Options de source : ${sourceOptions.length}, postes sans source fournisseur : ${noSource.length} (${noSource.map((line) => line.PurchaseRequisition + "/" + line.PurchaseRequisitionItem).join(", ")})`);
