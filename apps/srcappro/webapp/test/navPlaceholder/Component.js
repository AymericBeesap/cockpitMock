/**
 * Page de substitution du launchpad local : ouverte à la place des cibles de navigation
 * qui n'existent que dans le Launchpad réel (fiches SAP, transaction ME59N).
 * Elle affiche l'intention demandée, les paramètres reçus et ce qu'il faut configurer.
 */
sap.ui.define([
    "sap/ui/core/UIComponent",
    "sap/ui/model/json/JSONModel",
    "sap/m/Page",
    "sap/m/MessageStrip",
    "sap/m/ObjectHeader",
    "sap/m/ObjectAttribute",
    "sap/m/List",
    "sap/m/StandardListItem",
    "sap/m/Title"
], function (UIComponent, JSONModel, Page, MessageStrip, ObjectHeader, ObjectAttribute, List, StandardListItem, Title) {
    "use strict";

    return UIComponent.extend("zresa.navplaceholder.Component", {
        metadata: {
            manifest: "json"
        },

        createContent: function () {
            var oUrlParsing = sap.ushell.Container.getService("URLParsing");
            var oHash = oUrlParsing.parseShellHash(window.location.hash.replace(/^#/, "")) || {};
            var sIntent = oHash.semanticObject + "-" + oHash.action;
            var oStartupParameters = (this.getComponentData() || {}).startupParameters || {};

            var oModel = new JSONModel({
                intent: sIntent,
                target: {},
                steps: [],
                parameters: Object.keys(oStartupParameters).map(function (sName) {
                    return { name: sName, value: [].concat(oStartupParameters[sName]).join(", ") };
                })
            });

            var oTargetsModel = new JSONModel(sap.ui.require.toUrl("zresa/navplaceholder/targets.json"));
            oTargetsModel.dataLoaded().then(function () {
                var oTargets = oTargetsModel.getData();
                var oTarget = oTargets[sIntent] || { title: sIntent, steps: ["Aucune consigne pour cette intention : compléter navPlaceholder/targets.json."] };
                oModel.setProperty("/target", oTarget);
                oModel.setProperty("/steps", oTarget.steps.map(function (sStep, iIndex) {
                    return { text: (iIndex + 1) + ". " + sStep };
                }));
            });

            var oPage = new Page({
                title: "Navigation à configurer",
                showNavButton: true,
                navButtonPress: function () {
                    window.history.back();
                },
                content: [
                    new MessageStrip({
                        type: "Warning",
                        showIcon: true,
                        class: "sapUiSmallMargin",
                        text: "Cette cible n'existe que dans le Launchpad réel. Page affichée par le launchpad local à la place de #{/intent}."
                    }),
                    new ObjectHeader({
                        title: "{/target/title}",
                        number: "{/intent}",
                        attributes: [
                            new ObjectAttribute({ title: "Type de cible", text: "{/target/targetType}" }),
                            new ObjectAttribute({ title: "Origine de la navigation", text: "{/target/origin}" }),
                            new ObjectAttribute({ title: "Mode opératoire", text: "{/target/specReference}" })
                        ]
                    }),
                    new List({
                        headerText: "À faire pour activer cette navigation",
                        items: {
                            path: "/steps",
                            template: new StandardListItem({ title: "{text}", wrapping: true })
                        }
                    }),
                    new List({
                        headerText: "Paramètres transmis par la navigation",
                        noDataText: "Aucun paramètre",
                        items: {
                            path: "/parameters",
                            template: new StandardListItem({ title: "{name}", info: "{value}" })
                        }
                    })
                ]
            });
            oPage.setModel(oModel);
            return oPage;
        }
    });
});
