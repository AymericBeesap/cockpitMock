@EndUserText.label: 'Sources d''approvisionnement disponibles pour un poste de DA'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_RESA_SRC_QUERY'
@Search.searchable: true

-- Contenu de la pop-up de choix de la source.
--
-- Entité personnalisée (custom entity) : les lignes ne sont pas lues en base mais produites à
-- l'exécution par ZCL_RESA_SRC_QUERY, qui appelle ⟨PROGRAMME_SOURCES⟩ via ZCL_RESA_SRC_PROVIDER.
-- Aucune vue de customizing, aucune union CDS : la règle de détermination reste dans S/4.
--
-- Le poste de DA est obligatoire en filtre : hors contexte, la liste n'a pas de sens et la
-- classe de requête lève une exception explicite (message ZRESA_SRC 004).
--
-- Les annotations @UI.lineItem ci-dessous dessinent les colonnes de la boîte de dialogue
-- d'aide à la saisie ouverte depuis le paramètre SourceId de l'action SelectSource
-- (cf. ZD_ResaSourceSelParam). Aucun code JavaScript n'est nécessaire.

define custom entity ZI_ResaSourceOption
{
      @UI.hidden: true
  key PurchaseRequisition     : banfn;

      @UI.hidden: true
  key PurchaseRequisitionItem : bnfpo;

      @EndUserText.label: 'Type de source'
      @UI: { lineItem:       [ { position: 10, importance: #HIGH } ],
             selectionField: [ { position: 10 } ],
             textArrangement: #TEXT_ONLY }
      @ObjectModel.text.element: [ 'SourceTypeText' ]
  key SourceType              : zresa_srctype;

      @EndUserText.label: 'Source'
      @UI.lineItem: [ { position: 20, importance: #HIGH } ]
      @ObjectModel.text.element: [ 'SourceName' ]
  key SourceId                : zresa_srcid;

      @EndUserText.label: 'Type de source'
      SourceTypeText          : abap.char(40);

      @EndUserText.label: 'Désignation'
      @UI.lineItem: [ { position: 30, importance: #HIGH } ]
      SourceName              : zresa_srcname;

      -- champs d'affectation restitués par ⟨PROGRAMME_SOURCES⟩ et repris tels quels
      -- dans la demande d'achat par ZCL_RESA_SRC_PRUPDATE
      @UI.hidden: true
      Supplier                : lifnr;

      @UI.hidden: true
      PurchasingInfoRecord    : infnr;

      @UI.hidden: true
      PurchasingOrganization  : ekorg;

      @UI.hidden: true
      SupplyingPlant          : reswk;

      @EndUserText.label: 'Disponibilité'
      @UI.lineItem: [ { position: 40, criticality: 'AvailabilityCriticality', importance: #HIGH } ]
      @ObjectModel.text.element: [ 'AvailabilityText' ]
      Availability            : abap.char(1);

      @EndUserText.label: 'Disponibilité'
      AvailabilityText        : abap.char(40);

      @UI.hidden: true
      AvailabilityCriticality : abap.int1;

      @EndUserText.label: 'Quantité disponible'
      @UI.lineItem: [ { position: 50, importance: #MEDIUM } ]
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      AvailableQuantity       : abap.quan(13,3);

      BaseUnit                : meins;

      @EndUserText.label: 'Prix net'
      @UI.lineItem: [ { position: 60, importance: #MEDIUM } ]
      @Semantics.amount.currencyCode: 'Currency'
      NetPrice                : preis;

      Currency                : waers;

      @EndUserText.label: 'Délai (jours)'
      @UI.lineItem: [ { position: 70, importance: #MEDIUM } ]
      LeadTimeDays            : plifz;

      -- rang proposé par ⟨PROGRAMME_SOURCES⟩. Restitué à titre indicatif : conformément à la
      -- décision de conception, aucune source n'est présélectionnée, le choix reste manuel.
      @EndUserText.label: 'Rang'
      @UI.lineItem: [ { position: 80, importance: #LOW } ]
      SourceRank              : abap.int2;
}
