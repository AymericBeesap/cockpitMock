# Objets ABAP — détermination de la source d'approvisionnement

Objets à recopier dans Eclipse ADT, package `ZRESA_SRC`. Un fichier par objet.
Le mode opératoire complet est [.claude/Spec-SourceAppro-RAP.md](../.claude/Spec-SourceAppro-RAP.md).

Les vues CDS du suivi de la chaîne et du monitoring IDoc restent dans [../cds/](../cds/) :
ce sont des vues classiques OData V2, indépendantes de ce business object.

| Dossier | Contenu |
|---|---|
| [tables/](tables/) | Table applicative (source de données DDL ADT) |
| [cds/](cds/) | Vues d'interface, entité personnalisée, entité abstraite, vue racine, projection et extension de métadonnées |
| [bo/](bo/) | Définitions de comportement (`.bdef`) |
| [dcl/](dcl/) | Contrôles d'accès (`.asdcls`) |
| [classes/](classes/) | Classes et interface ABAP |
| [srv/](srv/) | Définition de service |

## Objets sans source à créer par formulaire

Ces objets n'ont pas de représentation texte : les créer dans ADT ou SE11 d'après le §Partie A
du mode opératoire.

| Objet | Type | Remarque |
|---|---|---|
| `ZRESA_SRCTYPE` | domaine + élément de données, `CHAR(4)` | valeurs fixes `EDI`, `WHSE`, `STOR` |
| `ZRESA_SRCID` | domaine + élément de données, `CHAR(10)` | fournisseur, entrepôt ou division voisine |
| `ZRESA_SRCNAME` | domaine + élément de données, `CHAR(60)` | désignation de la source |
| `ZRESA_SELSTAT` | domaine + élément de données, `CHAR(4)` | valeurs fixes `SEL`, `ERR` |
| `ZRESA_UPDMSG` | domaine + élément de données, `CHAR(220)` | message du BAPI en cas de refus |
| `ZRESA_SRC` | classe de messages | messages 001 à 006 |
| `ZUI_RESASRC_O4` | service binding | OData V4 - UI, sur `ZUI_RESASRC` |

## Ordre d'activation

1. Domaines et éléments de données, puis classe de messages `ZRESA_SRC`
2. `tables/ZTRESA_SRCSEL`
3. `classes/ZCX_RESA_SRC`
4. `classes/ZIF_RESA_SRC_PROVIDER` puis `classes/ZCL_RESA_SRC_PROVIDER`
5. `cds/ZI_ResaPurReqNoSource`
6. `cds/ZI_ResaSourceOption` puis `classes/ZCL_RESA_SRC_QUERY`
   (l'entité personnalisée s'active avant sa classe de requête, qui la référence comme type)
7. `cds/ZD_ResaSourceSelParam`
8. `cds/ZR_ResaPurReqSource`, puis `dcl/ZR_RESAPURREQSOURCE`
9. `bo/ZR_ResaPurReqSource.bdef`
10. `classes/ZCL_RESA_SRC_PRUPDATE` puis `classes/ZBP_R_RESAPURREQSOURCE`
11. `cds/ZC_ResaPurReqSource`, `cds/ZC_ResaPurReqSource.asddlxs`, `dcl/ZC_RESAPURREQSOURCE`,
    `bo/ZC_ResaPurReqSource.bdef`
12. `srv/ZUI_RESASRC` puis le service binding `ZUI_RESASRC_O4`, publication et
    `/IWFND/V4_ADMIN`

> **⚠️ Les valeurs entre chevrons `⟨…⟩` ne sont pas renseignées.** Les objets qui en contiennent
> ne s'activent pas tant qu'elles ne sont pas remplacées : c'est volontaire, elles sont listées
> en annexe du mode opératoire avec le relevé correspondant (R1 à R6).

## Ce qui n'est délibérément pas ici

- Aucune table de customizing de sources : la règle de détermination reste dans S/4, appelée par
  `ZCL_RESA_SRC_PROVIDER`.
- Aucun `COMMIT WORK` / `ROLLBACK WORK` / `BAPI_TRANSACTION_COMMIT` : la transaction appartient
  à la phase de sauvegarde RAP.
- Aucune opération `create` / `update` / `delete` exposée : une demande d'achat ne se crée pas
  dans cette application, c'est le rôle de la tuile standard.
