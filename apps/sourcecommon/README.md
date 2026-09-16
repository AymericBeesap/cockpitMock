# Extension mutualisée du socle « source d'approvisionnement »

Ce dossier n'est pas une application : c'est la partie d'interface **partagée par les écrans de
détermination** des deux alternatives. Il est servi sous `/apps/sourcecommon` par
`fiori-tools-servestatic` et déclaré dans chaque application par :

```json
"sap.ui5": {
  "resourceRoots": { "zresa.sourcecommon": "../sourcecommon" },
  "extends": { "extensions": { "sap.ui.viewExtensions": {
    "sap.suite.ui.generic.template.ObjectPage.view.Details": {
      "BeforeFacet|ZC_ResaPurReqWorklist|Sources": {
        "className": "sap.ui.core.Fragment",
        "fragmentName": "zresa.sourcecommon.SourceGuidance",
        "type": "XML"
      }
    }
  } } }
}
```

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `SourceGuidance.fragment.xml` | Synthèse des sources d'un poste : compteurs, source retenue, et alerte « aucune source fournisseur : la commande petite caisse est la seule option » | Écrans de détermination (Alt. 1 et Alt. 2) |

Le point d'extension `BeforeFacet|<entitySet>|<facetId>` est l'un des rares points offerts par les
templates Fiori elements V2 ; la vue List Report n'en expose aucun pour sa barre d'outils.

> **Les écrans de création n'utilisent pas d'extension.** Les actions `CreatePurchaseRequisition`
> et `CreateReplenishmentOrder` sont annotées en `DataFieldForAction` sans contexte : Fiori elements
> génère lui-même le formulaire de saisie des paramètres du function import.
