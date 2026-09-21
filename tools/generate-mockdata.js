"use strict";
// Génère les données de démonstration cohérentes des services mockés.
// Usage : node tools/generate-mockdata.js
//
// Trois jeux de données, un seul socle :
//   - la chaîne réservation / DA / commande (OData V2, zlr.resatracking) ;
//   - les IDocs d'intégration des réservations (OData V2, zlr.resaidoc) ;
//   - les postes sans source et leurs sources disponibles (OData V4, zlr.srcappro).
//
// Les postes de DA encore en attente de commande sont exactement ceux que l'application de
// détermination de la source présente : un poste sans source est un poste non converti.
const fs = require("fs");
const path = require("path");

const appsDir = path.join(__dirname, "..", "apps");
const DAY = 24 * 3600 * 1000;
const START = Date.UTC(2026, 5, 1); // 01/06/2026

const odataDate = (ms) => `/Date(${ms})/`;                                  // OData V2
const isoDate = (ms) => new Date(ms).toISOString().slice(0, 10);            // OData V4, Edm.Date
const isoStamp = (ms) => new Date(ms).toISOString().replace(/\.\d+Z$/, "Z"); // Edm.DateTimeOffset
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
    PR: "Demande d'achat en attente"
};

const tracking = [];
for (let i = 0; i < 36; i++) {
    const originType = i % 6 < 4 ? "RESA" : i % 6 === 4 ? "VENT" : "AUTR";
    // les postes anciens sont majoritairement convertis, les récents restent en attente
    const converted = i < 24 ? i % 5 !== 2 : i % 3 === 0;
    const [material, text] = materials[i % materials.length];
    const date = START + i * 2 * DAY;
    const quantity = 2 + ((i * 7) % 20);
    const price = [45.5, 129.9, 12.4, 18.75, 64.0, 32.2][i % 6];
    const purchaseOrder = converted ? String(4500012000 + i) : "";
    const stage = converted ? "PO" : "PR";

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
        FollowOnDocument: purchaseOrder,
        FollowOnDocumentType: converted ? "ZDI5" : "",
        OriginType: originType,
        OriginTypeText: originTexts[originType],
        ChainStage: stage,
        ChainStageText: stageTexts[stage],
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
        _index: i,
        _date: date,
        _quantity: quantity,
        _unitPrice: price
    });
}

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

// ------------------------------------------- postes sans source et sources disponibles
//
// En réel, les sources ne sont pas stockées : elles sont calculées à chaque appel par le
// programme S/4 (ZCL_RESA_SRC_PROVIDER). Ici, elles sont pré-générées par poste, ce qui donne
// au mock server exactement ce que l'entité personnalisée ZI_ResaSourceOption renvoie.
const ediSuppliers = [
    ["0000501234", "CENTRALE NATIONALE FOURNITURES", 2],
    ["0000502781", "NVC DISTRIBUTION", 3],
    ["0000503920", "EQUIPEMENT MAGASIN SAS", 5]
];
// les entrepôts livreurs sont des divisions : identifiant sur 4 caractères
const warehouses = [["WH01", "Entrepôt central Nord", 1], ["WH02", "Entrepôt Sud", 2]];
const neighbours = {
    "1000": [["1100", "Centre Lyon Part-Dieu", 1], ["1200", "Centre Grenoble", 2]],
    "1100": [["1000", "Centre Lyon Confluence", 1]],
    "1200": [["1100", "Centre Lyon Part-Dieu", 2], ["1000", "Centre Lyon Confluence", 3]]
};
const sourceTypeTexts = {
    EDI: "Fournisseur",
    WHSE: "Entrepôt",
    STOR: "Centre voisin"
};
const availabilityTexts = { A: "Disponible", B: "Partiellement disponible", C: "Non disponible" };
const availabilityCriticality = { A: 3, B: 2, C: 1 };

// postes pour lesquels une affectation a déjà été tentée et refusée par le standard
// (cas du relevé R4 : source entrepôt / centre voisin sur un poste de catégorie standard)
// (indices de postes encore en attente et disposant d'une source de type centre voisin)
const REFUSED_ITEMS = [12, 28];

const sourceOptions = [];
const addOption = (item, sourceType, sourceId, sourceName, availability, availableQty, leadTime, price, rank, assign) => {
    sourceOptions.push({
        PurchaseRequisition: item.PurchaseRequisition,
        PurchaseRequisitionItem: item.PurchaseRequisitionItem,
        SourceType: sourceType,
        SourceId: sourceId,
        SourceTypeText: sourceTypeTexts[sourceType],
        SourceName: sourceName,
        Supplier: assign.supplier || "",
        PurchasingInfoRecord: assign.infoRecord || "",
        PurchasingOrganization: assign.purchasingOrg || "",
        SupplyingPlant: assign.supplyingPlant || "",
        Availability: availability,
        AvailabilityText: availabilityTexts[availability],
        AvailabilityCriticality: availabilityCriticality[availability],
        AvailableQuantity: availableQty.toFixed(3),
        BaseUnit: item.BaseUnit,
        NetPrice: price.toFixed(2),
        Currency: item.Currency,
        LeadTimeDays: String(leadTime),
        SourceRank: rank
    });
};

const purReqItems = tracking
    .filter((item) => item.ChainStage === "PR")
    .map((item) => {
        const i = item._index;
        const quantity = item._quantity;
        const unitPrice = item._unitPrice;
        let rank = 0;

        // fournisseurs : disponibilité rendue par le programme de détermination
        if (i % 4 !== 3) {
            const [supplierId, supplierName, leadTime] = ediSuppliers[i % ediSuppliers.length];
            const partial = i % 3 === 2;
            // disponibilité partielle : la quantité annoncée est inférieure au besoin
            addOption(item, "EDI", supplierId, supplierName, partial ? "B" : "A",
                      partial ? Math.max(1, Math.floor(quantity * 0.6)) : quantity, leadTime, unitPrice, ++rank, {
                supplier: supplierId,
                infoRecord: String(5300000000 + i).slice(0, 10),
                purchasingOrg: "1000"
            });
        }
        if (i % 5 === 0) {
            const [supplierId, supplierName, leadTime] = ediSuppliers[(i + 1) % ediSuppliers.length];
            addOption(item, "EDI", supplierId, supplierName, "A", quantity, leadTime, unitPrice * 1.08, ++rank, {
                supplier: supplierId,
                infoRecord: String(5300001000 + i).slice(0, 10),
                purchasingOrg: "1000"
            });
        }
        // entrepôt livreur
        if (i % 3 !== 1) {
            const [whId, whName, leadTime] = warehouses[i % warehouses.length];
            const stock = i % 3 === 0 ? quantity + 12 : Math.max(1, Math.floor(quantity / 2));
            addOption(item, "WHSE", whId, whName, stock >= quantity ? "A" : "B", stock, leadTime, 0, ++rank, {
                supplyingPlant: whId
            });
        }
        // centres voisins
        if (i % 2 === 0) {
            for (const [plantId, plantName, leadTime] of neighbours[item.Plant]) {
                const stock = i % 4 === 0 ? quantity + 3 : Math.max(0, quantity - 4);
                addOption(item, "STOR", plantId, plantName, stock >= quantity ? "A" : "C", stock, leadTime, 0, ++rank, {
                    supplyingPlant: plantId
                });
            }
        }

        const refused = REFUSED_ITEMS.includes(i);
        const selectionStatus = refused ? "ERR" : "TODO";

        return {
            PurchaseRequisition: item.PurchaseRequisition,
            PurchaseRequisitionItem: item.PurchaseRequisitionItem,
            Plant: item.Plant,
            PurchasingGroup: item.PurchasingGroup,
            PurchasingOrganization: "1000",
            Material: item.Material,
            PurchaseRequisitionItemText: item.PurchaseRequisitionItemText,
            Reservation: item.Reservation,
            OriginType: item.OriginType === "RESA" ? "RESA" : "AUTR",
            OriginTypeText: item.OriginType === "RESA" ? "Réservation magasin" : "Autre besoin",
            PurReqDate: isoDate(item._date),
            DeliveryDate: isoDate(item._date + 14 * DAY),
            RequestedQuantity: item.RequestedQuantity,
            BaseUnit: item.BaseUnit,
            ItemAmount: Number(item.ItemAmount).toFixed(2),
            Currency: item.Currency,
            SelectedSourceType: refused ? "STOR" : "",
            SelectedSourceId: refused ? neighbours[item.Plant][0][0] : "",
            SelectedSourceName: refused ? neighbours[item.Plant][0][1] : "",
            SelectedNetPrice: refused ? "0.00" : null,
            SelectedLeadTimeDays: refused ? String(neighbours[item.Plant][0][2]) : null,
            SelectionStatus: selectionStatus,
            SelectionStatusText: refused ? "Affectation refusée par la demande d'achat" : "À traiter",
            SelectionCriticality: refused ? 1 : 2,
            SelectionMessage: refused
                ? "Poste 00010 : modification de la division livreuse impossible, catégorie de poste incompatible"
                : "",
            CreatedBy: refused ? "ACHAT01" : "",
            CreatedAt: refused ? isoStamp(item._date + 3 * DAY) : null,
            LastChangedBy: refused ? "ACHAT01" : "",
            LastChangedAt: refused ? isoStamp(item._date + 3 * DAY) : null
        };
    });

// ---------------------------------------------------------------- écriture
const strip = (line) => {
    const copy = { ...line };
    delete copy._date;
    delete copy._index;
    delete copy._quantity;
    delete copy._unitPrice;
    return copy;
};
write("resatracking/webapp/localService/ZCRESATRACK_CDS/data/ZC_ResaChainTracking.json", tracking.map(strip));
write("resaidoc/webapp/localService/ZCRESAIDTRACK_CDS/data/ZC_ResaIdocTracking.json", idocs.map(strip));
write("srcappro/webapp/localService/ZUI_RESASRC/data/PurReqItem.json", purReqItems);
write("srcappro/webapp/localService/ZUI_RESASRC/data/SourceOption.json", sourceOptions);

const open = tracking.filter((item) => item.ChainStage === "PR").length;
const resa = tracking.filter((item) => item.OriginType === "RESA");
const resaConverted = resa.filter((item) => item.ChainStage === "PO").length;
const withoutSource = purReqItems.filter(
    (line) => !sourceOptions.some((option) => option.PurchaseRequisition === line.PurchaseRequisition && option.PurchaseRequisitionItem === line.PurchaseRequisitionItem)
);
console.log(`Postes : ${tracking.length}, en attente : ${open}, conversion RESA : ${((resaConverted / resa.length) * 100).toFixed(1)} %`);
console.log(`IDocs : ${idocs.length}, en erreur : ${idocs.filter((idoc) => idoc.IntegrationStatus === "KO").length}`);
console.log(`Postes sans source : ${purReqItems.length}, dont refusés par le standard : ${purReqItems.filter((line) => line.SelectionStatus === "ERR").length}`);
console.log(`Options de source : ${sourceOptions.length}, postes sans aucune source proposée : ${withoutSource.length}`);
