@AbapCatalog.sqlViewName: 'ZIRESASRCSTO'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source d''appro - centres voisins'

-- Socle commun de détermination de la source d'approvisionnement (3/4).
-- Restitue les centres voisins disposant de stock disponible à la vente.
--
-- ⚠️ À BRANCHER : la notion de « centre voisin » doit venir d'une table de proximité
--    (ZTCENTRE_VOISIN ou équivalent : zone de chalandise, distance, tournée de transport).
--    Le stock doit être le stock disponible à la vente, pas le stock physique.
define view ZI_ResaSrcStore
  as select from ZI_ResaChainCube  as Item

    inner join   ZI_ResaStoreNeighbour as Neighbour   -- TODO : table de proximité à créer
      on Neighbour.Plant = Item.Plant

    inner join   I_MaterialStock   as Stock
      on  Stock.Material = Item.Material
      and Stock.Plant    = Neighbour.NeighbourPlant

    left outer join I_Plant        as NeighbourPlant
      on NeighbourPlant.Plant = Neighbour.NeighbourPlant
{
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,

      cast( 'STOR' as abap.char(4) )                   as SourceType,
      cast( 'Centre voisin' as abap.char(40) )         as SourceTypeText,

      cast( Stock.Plant as abap.char(10) )             as SourceId,
      cast( NeighbourPlant.PlantName as abap.char(80) ) as SourceName,

      case when Stock.MatlStkUnrstrctdUseQty >= Item.RequestedQuantity
           then cast( 'A' as abap.char(1) )
           else cast( 'C' as abap.char(1) )
      end                                              as Availability,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Stock.MatlStkUnrstrctdUseQty                     as AvailableQuantity,
      Item.BaseUnit,

      Neighbour.LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      cast( 0 as abap.curr(11,2) )                     as NetPrice,
      Item.Currency
}
where Item.PurchaseOrder = ''
