@AbapCatalog.sqlViewName: 'ZIRESASRCWHS'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source d''appro - entrepôt'

-- Socle commun de détermination de la source d'approvisionnement (2/4).
-- Restitue le stock disponible en entrepôt (divisions WH).
--
-- ⚠️ À BRANCHER : restreindre aux divisions entrepôt du périmètre (table de paramétrage Z
--    plutôt que le filtre sur le préfixe ci-dessous) et utiliser le stock réellement
--    disponible (ATP) et non le stock non affecté.
define view ZI_ResaSrcWhse
  as select from ZI_ResaChainCube as Item

    inner join   I_MaterialStock  as Stock
      on  Stock.Material = Item.Material
      and Stock.Plant   <> Item.Plant
{
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,

      cast( 'WHSE' as abap.char(4) )                   as SourceType,
      cast( 'Entrepôt' as abap.char(40) )              as SourceTypeText,

      cast( Stock.Plant as abap.char(10) )             as SourceId,
      cast( Stock.Plant as abap.char(80) )             as SourceName,

      case when Stock.MatlWrhsStkQtyInMatlBaseUnit >= Item.RequestedQuantity
           then cast( 'A' as abap.char(1) )
           else cast( 'B' as abap.char(1) )
      end                                              as Availability,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Stock.MatlWrhsStkQtyInMatlBaseUnit               as AvailableQuantity,
      Item.BaseUnit,

      cast( 1 as abap.int4 )                           as LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      cast( 0 as abap.curr(11,2) )                     as NetPrice,
      Item.Currency
}
where Item.PurchaseOrder = ''
  and Stock.Plant        like 'WH%'
