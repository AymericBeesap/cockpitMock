@AbapCatalog.sqlViewName: 'ZIRESAIDMAX'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Dernier statut de chaque IDoc'

define view ZI_ResaIdocLastStatus
  as select from edids
{
  key docnum              as IDocNumber,
      max( countr )       as LastCounter
}
group by
  docnum
