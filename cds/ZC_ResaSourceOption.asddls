@AbapCatalog.sqlViewName: 'ZCRESASRCOPT'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Options de source d''approvisionnement'
@Metadata.allowExtensions: true
@OData.publish: true

-- Vue de consommation du socle commun : alimente le comparatif des sources affiché
-- dans la page objet des deux écrans de détermination (Alternative 1 et Alternative 2).
define view ZC_ResaSourceOption
  as select from    ZI_ResaSourceAvail as Source

    left outer join ztresa_srcsel      as Selection   -- TODO : table de travail du choix de source
      on  Selection.banfn = Source.PurchaseRequisition
      and Selection.bnfpo = Source.PurchaseRequisitionItem
{
      -- clé technique stable, nécessaire à l'exposition OData
  key concat_with_space( Source.PurchaseRequisition,
        concat_with_space( Source.PurchaseRequisitionItem,
          concat_with_space( Source.SourceType, Source.SourceId, 0 ), 0 ), 0 ) as SourceOptionId,

      Source.PurchaseRequisition,
      Source.PurchaseRequisitionItem,

      @ObjectModel.text.element: [ 'SourceTypeText' ]
      Source.SourceType,
      Source.SourceTypeText,

      Source.SourceId,
      Source.SourceName,

      @ObjectModel.text.element: [ 'AvailabilityText' ]
      Source.Availability,
      cast( case Source.Availability
              when 'A' then 'Disponible'
              when 'B' then 'Partiellement disponible'
              else          'Non disponible'
            end as abap.char(40) )                     as AvailabilityText,

      -- couleur de la pastille de disponibilité
      case Source.Availability
        when 'A' then 3
        when 'B' then 2
        else          1
      end                                              as SourceCriticality,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Source.AvailableQuantity,
      Source.BaseUnit,

      Source.LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      Source.NetPrice,
      Source.Currency,

      case when Selection.srctype = Source.SourceType
            and Selection.srcid   = Source.SourceId
           then cast( 'X' as abap.char(1) )
           else cast( '' as abap.char(1) )
      end                                              as IsSelected
}
