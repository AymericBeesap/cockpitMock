"! <p class="shorttext synchronized">Détermination de la source - implémentation</p>
"!
"! Ce fichier regroupe les deux onglets de la classe de comportement dans ADT :
"! la classe globale (vide, c'est la règle) puis les types locaux.
"! Copier chaque section dans l'onglet correspondant.
"!
"! Découpage des responsabilités :
"! <ul>
"! <li><em>action SelectSource</em> — tout ce qui peut être contrôlé l'est ici : la source existe
"!     toujours, l'affectation est simulée par BAPI_PR_CHANGE en mode TESTRUN. C'est la seule
"!     phase où un refus peut être affiché à l'écran.</li>
"! <li><em>sauvegarde</em> — l'affectation réelle et l'écriture de la trace. Un refus du standard
"!     à ce stade ne peut plus être remonté à l'écran : il est enregistré dans ZTRESA_SRCSEL
"!     (statut ERR + message) et le poste reste dans la liste de travail.</li>
"! </ul>
"!
"! Aucun COMMIT WORK, aucun ROLLBACK WORK dans ce fichier : la transaction appartient à RAP.

" ======================================================================================
" Onglet « Global Class »
" ======================================================================================
CLASS zbp_r_resapurreqsource DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zr_resapurreqsource.
ENDCLASS.

CLASS zbp_r_resapurreqsource IMPLEMENTATION.
ENDCLASS.


" ======================================================================================
" Onglet « Local Types »
" ======================================================================================

"! Tampon de la source retenue, entre l'action et la sauvegarde.
"! L'action a déjà interrogé ⟨PROGRAMME_SOURCES⟩ et simulé l'affectation ; la sauvegarde a besoin
"! des champs d'affectation complets (fournisseur, fiche info, organisation d'achat, division
"! livreuse) que la vue du business object n'expose pas. Les repasser par ce tampon évite un
"! second appel au programme de détermination.
CLASS lcl_src_buffer DEFINITION CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_entry,
        pur_req      TYPE banfn,
        pur_req_item TYPE bnfpo,
        source       TYPE zif_resa_src_provider=>ty_source,
      END OF ty_entry,
      tt_entry TYPE SORTED TABLE OF ty_entry WITH UNIQUE KEY pur_req pur_req_item.

    CLASS-METHODS set
      IMPORTING iv_pur_req      TYPE banfn
                iv_pur_req_item TYPE bnfpo
                is_source       TYPE zif_resa_src_provider=>ty_source.

    CLASS-METHODS get
      IMPORTING iv_pur_req       TYPE banfn
                iv_pur_req_item  TYPE bnfpo
      RETURNING VALUE(rs_source) TYPE zif_resa_src_provider=>ty_source.

    CLASS-METHODS clear.

  PRIVATE SECTION.
    CLASS-DATA gt_entry TYPE tt_entry.

ENDCLASS.

CLASS lcl_src_buffer IMPLEMENTATION.

  METHOD set.
    DELETE gt_entry WHERE pur_req      = iv_pur_req
                      AND pur_req_item = iv_pur_req_item.
    INSERT VALUE #( pur_req      = iv_pur_req
                    pur_req_item = iv_pur_req_item
                    source       = is_source ) INTO TABLE gt_entry.
  ENDMETHOD.

  METHOD get.
    rs_source = VALUE #( gt_entry[ pur_req      = iv_pur_req
                                   pur_req_item = iv_pur_req_item ]-source OPTIONAL ).
  ENDMETHOD.

  METHOD clear.
    CLEAR gt_entry.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_purreqitem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR PurReqItem RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurReqItem RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK PurReqItem.

    METHODS selectsource FOR MODIFY
      IMPORTING keys FOR ACTION PurReqItem~SelectSource RESULT result.

ENDCLASS.

CLASS lhc_purreqitem IMPLEMENTATION.

  METHOD get_instance_authorizations.

    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqItem
        FIELDS ( Plant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      FAILED failed.

    LOOP AT lt_item INTO DATA(ls_item).

      " Retenir une source modifie la demande d'achat : activité 02, sur la division du poste.
      AUTHORITY-CHECK OBJECT 'M_BANF_WRK'
        ID 'ACTVT' FIELD '02'
        ID 'WERKS' FIELD ls_item-Plant.

      DATA(lv_granted) = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                 ELSE                  if_abap_behv=>auth-unauthorized ).

      " Seule l'action est exposée : il n'y a rien d'autre à autoriser.
      APPEND VALUE #( %tky                 = ls_item-%tky
                      %action-SelectSource = lv_granted ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqItem
        FIELDS ( Plant Material )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      FAILED failed.

    LOOP AT lt_item INTO DATA(ls_item).

      " Sans division ni article, ⟨PROGRAMME_SOURCES⟩ ne peut rien proposer : le bouton est
      " désactivé plutôt que d'ouvrir une pop-up vide (cas des postes sur texte libre).
      DATA(lv_enabled) = COND #(
        WHEN ls_item-Plant IS NOT INITIAL AND ls_item-Material IS NOT INITIAL
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ).

      APPEND VALUE #( %tky                 = ls_item-%tky
                      %action-SelectSource = lv_enabled ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD lock.

    " Verrou pessimiste sur le poste de demande d'achat : sans draft, deux acheteurs ne
    " doivent pas retenir deux sources différentes sur le même poste.
    "
    " ⚠️ À vérifier (relevé R3) : nom réel de l'objet de verrouillage de EBAN et de ses
    " paramètres (SE11, recherche sur la table EBAN).
    LOOP AT keys INTO DATA(ls_key).

      CALL FUNCTION 'ENQUEUE_⟨OBJET_VERROU_EBAN⟩'
        EXPORTING
          mode_eban      = 'E'
          banfn          = ls_key-PurchaseRequisition
          _scope         = '1'
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqitem.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZRESA_SRC'
                                            number   = '003'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = ls_key-PurchaseRequisition
                                            v2       = sy-msgv1 ) ) TO reported-purreqitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD selectsource.

    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqItem
        FIELDS ( Plant Material RequestedQuantity BaseUnit DeliveryDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      FAILED failed.

    LOOP AT keys INTO DATA(ls_key).

      DATA(ls_item) = VALUE #( lt_item[ %tky = ls_key-%tky ] OPTIONAL ).
      IF ls_item IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqitem.
        CONTINUE.
      ENDIF.

      " Une source doit être retenue : la pop-up peut être quittée sans choix.
      IF ls_key-%param-SourceId IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqitem.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZRESA_SRC'
                                            number   = '005'
                                            severity = if_abap_behv_message=>severity-error )
                      ) TO reported-purreqitem.
        CONTINUE.
      ENDIF.

      " La clé du poste vient de l'instance, pas des paramètres : les paramètres de contexte
      " ne servent qu'à filtrer la pop-up et ne sont pas dignes de confiance.
      DATA(ls_request) = VALUE zif_resa_src_provider=>ty_request(
        plant         = ls_item-Plant
        material      = ls_item-Material
        quantity      = ls_item-RequestedQuantity
        base_unit     = ls_item-BaseUnit
        delivery_date = ls_item-DeliveryDate ).

      DATA ls_source TYPE zif_resa_src_provider=>ty_source.

      TRY.
          " Relecture : la pop-up a pu être ouverte plusieurs minutes plus tôt.
          ls_source = zcl_resa_src_provider=>get_instance( )->get_source(
            is_request     = ls_request
            iv_source_type = ls_key-%param-SourceType
            iv_source_id   = ls_key-%param-SourceId ).
        CATCH zcx_resa_src INTO DATA(lo_error).
          APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqitem.
          APPEND VALUE #( %tky = ls_key-%tky
                          %msg = lo_error ) TO reported-purreqitem.
          CONTINUE.
      ENDTRY.

      " Simulation de l'affectation : c'est ici, et nulle part plus tard, qu'un refus du
      " standard peut être montré à l'acheteur.
      DATA(ls_check) = zcl_resa_src_prupdate=>assign_source(
        iv_pur_req      = ls_item-PurchaseRequisition
        iv_pur_req_item = ls_item-PurchaseRequisitionItem
        is_source       = ls_source
        iv_testrun      = abap_true ).

      IF ls_check-success = abap_false.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-purreqitem.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = CONV string( ls_check-message ) )
                      ) TO reported-purreqitem.
        CONTINUE.
      ENDIF.

      lcl_src_buffer=>set( iv_pur_req      = ls_item-PurchaseRequisition
                           iv_pur_req_item = ls_item-PurchaseRequisitionItem
                           is_source       = ls_source ).

      MODIFY ENTITIES OF zr_resapurreqsource IN LOCAL MODE
        ENTITY PurReqItem
          UPDATE FIELDS ( SelectedSourceType SelectedSourceId SelectedSourceName
                          SelectedNetPrice SelectedLeadTimeDays SelectionMessage )
          WITH VALUE #( ( %tky                 = ls_key-%tky
                          SelectedSourceType   = ls_source-source_type
                          SelectedSourceId     = ls_source-source_id
                          SelectedSourceName   = ls_source-source_name
                          SelectedNetPrice     = ls_source-net_price
                          SelectedLeadTimeDays = ls_source-lead_time_days
                          SelectionMessage     = space ) )
        FAILED   failed
        REPORTED reported.

    ENDLOOP.

    " Résultat de l'action : l'instance mise à jour, pour que l'écran rafraîchisse la ligne.
    READ ENTITIES OF zr_resapurreqsource IN LOCAL MODE
      ENTITY PurReqItem
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_line IN lt_result
                      ( %tky   = ls_line-%tky
                        %param = ls_line ) ).

  ENDMETHOD.

ENDCLASS.


CLASS lsc_zr_resapurreqsource DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified    REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zr_resapurreqsource IMPLEMENTATION.

  METHOD save_modified.

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT update-purreqitem INTO DATA(ls_update).

      DATA(ls_source) = lcl_src_buffer=>get( iv_pur_req      = ls_update-PurchaseRequisition
                                             iv_pur_req_item = ls_update-PurchaseRequisitionItem ).
      IF ls_source IS INITIAL.
        CONTINUE.
      ENDIF.

      " Affectation réelle de la source au poste de demande d'achat, sans COMMIT :
      " c'est le COMMIT de RAP qui la rendra définitive, ou son ROLLBACK qui l'annulera.
      DATA(ls_result) = zcl_resa_src_prupdate=>assign_source(
        iv_pur_req      = ls_update-PurchaseRequisition
        iv_pur_req_item = ls_update-PurchaseRequisitionItem
        is_source       = ls_source ).

      " Reprise des données d'administration si le poste avait déjà fait l'objet d'un choix.
      SELECT SINGLE created_by, created_at
        FROM ztresa_srcsel
        WHERE banfn = @ls_update-PurchaseRequisition
          AND bnfpo = @ls_update-PurchaseRequisitionItem
        INTO @DATA(ls_admin).

      DATA(ls_db) = VALUE ztresa_srcsel(
        banfn      = ls_update-PurchaseRequisition
        bnfpo      = ls_update-PurchaseRequisitionItem
        srctype    = ls_source-source_type
        srcid      = ls_source-source_id
        srcname    = ls_source-source_name
        lifnr      = ls_source-supplier
        infnr      = ls_source-info_record
        ekorg      = ls_source-purchasing_org
        reswk      = ls_source-supplying_plant
        preis      = ls_source-net_price
        waers      = ls_source-currency
        plifz      = ls_source-lead_time_days
        " Le refus du standard en phase de sauvegarde ne peut plus être affiché : il est
        " enregistré ici, et c'est lui que la liste de travail restitue en rouge.
        selstat    = COND #( WHEN ls_result-success = abap_true THEN 'SEL' ELSE 'ERR' )
        updmsg     = ls_result-message
        created_by = COND #( WHEN ls_admin-created_by IS INITIAL THEN sy-uname
                             ELSE ls_admin-created_by )
        created_at = COND #( WHEN ls_admin-created_at IS INITIAL THEN lv_now
                             ELSE ls_admin-created_at )
        changed_by = sy-uname
        changed_at = lv_now ).

      " MODIFY et non UPDATE : la ligne n'existe pas tant que rien n'a été retenu.
      MODIFY ztresa_srcsel FROM @ls_db.

    ENDLOOP.

    lcl_src_buffer=>clear( ).

  ENDMETHOD.


  METHOD cleanup_finalize.

    " ⚠️ À vérifier (relevé R3) : nom réel de l'objet de verrouillage de EBAN.
    CALL FUNCTION 'DEQUEUE_⟨OBJET_VERROU_EBAN⟩'
      EXPORTING
        _scope = '1'.

    lcl_src_buffer=>clear( ).

  ENDMETHOD.

ENDCLASS.
