@EndUserText.label: 'Paramètres de l''action « Retenir une source »'

-- Paramètre de l'action SelectSource de ZR_ResaPurReqSource.
--
-- C'est l'annotation @Consumption.valueHelpDefinition ci-dessous, et elle seule, qui produit
-- la pop-up : Fiori elements V4 ouvre une boîte de dialogue d'aide à la saisie sur SourceId,
-- alimentée par l'entité personnalisée ZI_ResaSourceOption, filtrée sur le poste de DA.
--
-- PurchaseRequisition / PurchaseRequisitionItem ne servent qu'à ce filtrage : ils portent
-- volontairement le nom des propriétés de l'entité de rattachement pour être pré-alimentés par
-- le contexte de la ligne sélectionnée. L'implémentation ABAP ne leur fait pas confiance et relit
-- la clé sur l'instance (cf. ZBP_R_RESAPURREQSOURCE).
--
-- ⚠️ À vérifier (relevé R5) — pré-alimentation des paramètres d'action depuis le contexte et
-- aide à la saisie sur paramètre d'action sous SAPUI5 1.96. Si l'un des deux ne fonctionne pas,
-- appliquer le repli documenté au §2.3 du mode opératoire (sous-section de page objet).

define abstract entity ZD_ResaSourceSelParam
{
      @EndUserText.label: 'Demande d''achat'
      @UI.hidden: true
  PurchaseRequisition     : banfn;

      @EndUserText.label: 'Poste'
      @UI.hidden: true
  PurchaseRequisitionItem : bnfpo;

      -- renseigné automatiquement à partir de la ligne retenue dans la pop-up (usage: #RESULT)
      @EndUserText.label: 'Type de source'
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ResaSourceOption', element: 'SourceType' },
                                            additionalBinding: [ { localElement: 'PurchaseRequisition',
                                                                   element:      'PurchaseRequisition',
                                                                   usage:        #FILTER },
                                                                 { localElement: 'PurchaseRequisitionItem',
                                                                   element:      'PurchaseRequisitionItem',
                                                                   usage:        #FILTER },
                                                                 { localElement: 'SourceId',
                                                                   element:      'SourceId',
                                                                   usage:        #RESULT } ] } ]
  SourceType              : zresa_srctype;

      @EndUserText.label: 'Source retenue'
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ResaSourceOption', element: 'SourceId' },
                                            additionalBinding: [ { localElement: 'PurchaseRequisition',
                                                                   element:      'PurchaseRequisition',
                                                                   usage:        #FILTER },
                                                                 { localElement: 'PurchaseRequisitionItem',
                                                                   element:      'PurchaseRequisitionItem',
                                                                   usage:        #FILTER },
                                                                 { localElement: 'SourceType',
                                                                   element:      'SourceType',
                                                                   usage:        #RESULT } ] } ]
  SourceId                : zresa_srcid;
}
