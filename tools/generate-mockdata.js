"use strict";
// Génère les données de démonstration cohérentes des quatre services mockés.
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
const stageTexts = { PO: "Commande d'achat créée", PR: "Demande d'achat en attente" };

const tracking = [];
for (let i = 0; i < 36; i++) {
    const originType = i % 6 < 4 ? "RESA" : i % 6 === 4 ? "VENT" : "AUTR";
    // les postes anciens sont majoritairement convertis, les récents restent en attente
    const converted = i < 24 ? i % 5 !== 2 : i % 3 === 0;
    const [material, text] = materials[i % materials.length];
    const date = START + i * 2 * DAY;
    const quantity = 2 + ((i * 7) % 20);
    const price = [45.5, 129.9, 12.4, 18.75, 64.0, 32.2][i % 6];

    tracking.push({
        PurchaseRequisition: String(10010001 + Math.floor(i / 2)).padStart(10, "0"),
        PurchaseRequisitionItem: String((i % 2) * 10 + 10).padStart(5, "0"),
        Reservation: originType === "RESA" ? `RES${String(260001 + i).padStart(7, "0")}` : "",
        SalesOrder: originType === "VENT" ? String(30004500 + i).padStart(10, "0") : "",
        SalesOrderItem: originType === "VENT" ? "000010" : "",
        SalesOrderItemText: originType === "VENT" ? text : "",
        PurchaseOrder: converted ? String(4500012000 + i) : "",
        PurchaseOrderItem: converted ? "00010" : "",
        PurchaseOrderItemText: converted ? text : "",
        OriginType: originType,
        OriginTypeText: originTexts[originType],
        ChainStage: converted ? "PO" : "PR",
        ChainStageText: stageTexts[converted ? "PO" : "PR"],
        ChainCriticality: converted ? 3 : 2,
        Plant: plants[i % 3],
        PurchasingGroup: groups[i % 2],
        Material: material,
        PurchaseRequisitionItemText: text,
        PurReqDate: odataDate(date),
        RequestedQuantity: quantity.toFixed(3),
        BaseUnit: "PC",
        ItemAmount: (quantity * price).toFixed(3),
        Currency: "EUR",
        _date: date
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

// ---------------------------------------------------------------- écriture
const strip = ({ _date, ...line }) => line;
write("resatracking/webapp/localService/ZCRESATRACK_CDS/data/ZC_ResaChainTracking.json", tracking.map(strip));
write("resacockpit/webapp/localService/ZCRESAKPI_CDS/data/ZC_ResaChainQuery.json", chainQuery);
write("resacockpit/webapp/localService/ZCRESAIDKPI_CDS/data/ZC_ResaIdocQuery.json", idocQuery);
write("resaidoc/webapp/localService/ZCRESAIDTRACK_CDS/data/ZC_ResaIdocTracking.json", idocs.map(strip));

const open = tracking.filter((item) => item.ChainStage === "PR").length;
const resa = tracking.filter((item) => item.OriginType === "RESA");
const resaConverted = resa.filter((item) => item.ChainStage === "PO").length;
console.log(`Postes : ${tracking.length}, en attente : ${open}, conversion RESA : ${((resaConverted / resa.length) * 100).toFixed(1)} %`);
console.log(`IDocs : ${idocs.length}, en erreur : ${idocs.filter((idoc) => idoc.IntegrationStatus === "KO").length}`);
