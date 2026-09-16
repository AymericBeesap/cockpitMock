@AbapCatalog.sqlViewName: 'ZIRESASRCEDI'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source d''appro - fournisseurs EDI'

-- Socle commun de détermination de la source d'approvisionnement (1/4).
-- Restitue, par poste de demande d'achat, les fournisseurs EDI candidats.
--
-- ⚠️ À BRANCHER : la disponibilité « A » provient du contrôle fournisseur du message ZC10.
--    Remplacer le calcul ci-dessous par la lecture réelle (table de disponibilité ou appel
--    au module de contrôle) et restreindre aux fournisseurs réellement EDI (NVC incluse).
define view ZI_ResaSrcEdi
  as select from    ZI_ResaChainCube     as Item

    inner join      I_PurchasingInfoRecord as InfoRecord
      on  InfoRecord.Material = Item.Material
      and InfoRecord.Plant    = Item.Plant

    left outer join I_Supplier           as Supplier
      on Supplier.Supplier = InfoRecord.Supplier
{
  key Item.PurchaseRequisition,
  key Item.PurchaseRequisitionItem,

      cast( 'EDI' as abap.char(4) )                    as SourceType,
      cast( 'Fournisseur EDI' as abap.char(40) )       as SourceTypeText,

      cast( InfoRecord.Supplier as abap.char(10) )     as SourceId,
      cast( Supplier.SupplierName as abap.char(80) )   as SourceName,

      -- TODO disponibilité réelle (message ZC10)
      cast( 'A' as abap.char(1) )                      as Availability,

      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Item.RequestedQuantity                           as AvailableQuantity,
      Item.BaseUnit,

      cast( 2 as abap.int4 )                           as LeadTimeDays,

      @Semantics.amount.currencyCode: 'Currency'
      InfoRecord.NetPriceAmount                        as NetPrice,
      InfoRecord.Currency
}
where Item.PurchaseOrder = ''
