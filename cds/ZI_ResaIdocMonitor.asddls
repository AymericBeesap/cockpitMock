@AbapCatalog.sqlViewName: 'ZIRESAIDOC'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitoring des IDocs de réservation magasin'

define view ZI_ResaIdocMonitor
  as select from edidc as Header

    inner join ZI_ResaIdocLastStatus as LastStatus
      on Header.docnum = LastStatus.IDocNumber

    inner join edids as Status
      on  Status.docnum = LastStatus.IDocNumber
      and Status.countr = LastStatus.LastCounter

    left outer join teds2 as StatusText
      on  StatusText.status = Header.status
      and StatusText.langua = $session.system_language
{
  key Header.docnum                          as IDocNumber,

      Header.mestyp                          as MessageType,
      Header.idoctp                          as IDocType,
      Header.sndprn                          as SenderPartner,
      Header.credat                          as CreationDate,
      Header.cretim                          as CreationTime,
      Header.status                          as IDocStatus,
      StatusText.descrp                      as IDocStatusText,

      Status.stamid                          as MessageClass,
      Status.stamno                          as MessageNumber,
      Status.statxt                          as MessageText,

      -- regroupement fonctionnel du statut (à aligner sur le relevé du chapitre 2.3)
      case Header.status
        when '53' then 'OK'
        when '62' then 'OK'
        when '51' then 'KO'
        when '56' then 'KO'
        when '61' then 'KO'
        when '63' then 'KO'
        when '68' then 'AB'
        else           'EC'
      end                                    as IntegrationStatus,

      -- criticité pour l'affichage
      case Header.status
        when '53' then 3
        when '62' then 3
        when '51' then 1
        when '56' then 1
        when '61' then 1
        when '63' then 1
        when '68' then 0
        else           2
      end                                    as StatusCriticality,

      case Header.status
        when '51' then 1
        when '56' then 1
        when '61' then 1
        when '63' then 1
        else           0
      end                                    as IDocErrorCount,

      1                                      as IDocCount
}
where Header.mestyp = 'Z_CREA_PR'
  and Header.direct = '2'
