"! <p class="shorttext synchronized">Affectation de la source à la demande d'achat</p>
"! Enveloppe de BAPI_PR_CHANGE. Aucun COMMIT, aucun ROLLBACK : la transaction appartient à la
"! phase de sauvegarde RAP, qui valide ou annule l'ensemble.
"!
"! Le mode simulation (iv_testrun) est appelé par l'action, avant toute écriture, pour que
"! l'acheteur voie immédiatement le refus du standard ; le mode réel est appelé en sauvegarde.
"!
"! ⚠️ À vérifier (relevé R4) — trois points, dans cet ordre :
"! <ol>
"! <li>l'existence du paramètre TESTRUN sur BAPI_PR_CHANGE dans le système ;</li>
"! <li>les noms de champs de BAPIMEREQITEMIMP / BAPIMEREQITEMX utilisés ci-dessous ;</li>
"! <li>surtout : ce que le standard accepte de modifier sur un poste existant. Le fournisseur
"!     fixe et la fiche info passent ; la division livreuse suppose une catégorie de poste U,
"!     qu'un poste créé en catégorie standard ne prend pas. Dans ce cas le BAPI refuse, le refus
"!     est tracé dans ZTRESA_SRCSEL et le poste reste dans la liste de travail — il n'est jamais
"!     masqué. Arbitrage à mener avec le fonctionnel MM avant la mise en service.</li>
"! </ol>
CLASS zcl_resa_src_prupdate DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_result,
        success TYPE abap_bool,
        message TYPE zresa_updmsg,
      END OF ty_result.

    "! Affecte la source retenue au poste de demande d'achat.
    "! @parameter iv_testrun | simulation : contrôle complet, aucune écriture
    CLASS-METHODS assign_source
      IMPORTING iv_pur_req       TYPE banfn
                iv_pur_req_item  TYPE bnfpo
                is_source        TYPE zif_resa_src_provider=>ty_source
                iv_testrun       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.

    "! Concatène les messages d'erreur du BAPI en un texte unique, tronqué à la longueur du
    "! champ de trace.
    CLASS-METHODS error_text
      IMPORTING it_return      TYPE bapiret2_t
      RETURNING VALUE(rv_text) TYPE zresa_updmsg.

ENDCLASS.


CLASS zcl_resa_src_prupdate IMPLEMENTATION.

  METHOD assign_source.

    DATA lt_item   TYPE STANDARD TABLE OF bapimereqitemimp.
    DATA lt_itemx  TYPE STANDARD TABLE OF bapimereqitemx.
    DATA lt_return TYPE bapiret2_t.

    " Champs d'affectation : ce que la source porte, et rien de plus. C'est
    " ⟨PROGRAMME_SOURCES⟩ qui décide de ce qui caractérise une source.
    APPEND VALUE #( preq_item  = iv_pur_req_item
                    fixed_vend = is_source-supplier
                    info_rec   = is_source-info_record
                    purch_org  = is_source-purchasing_org
                    suppl_plnt = is_source-supplying_plant ) TO lt_item.

    APPEND VALUE #( preq_item   = iv_pur_req_item
                    preq_itemx  = abap_true
                    fixed_vend  = abap_true
                    info_rec    = abap_true
                    purch_org   = abap_true
                    suppl_plnt  = abap_true ) TO lt_itemx.

    CALL FUNCTION 'BAPI_PR_CHANGE'
      EXPORTING
        number  = iv_pur_req
        testrun = iv_testrun
      TABLES
        pritem  = lt_item
        pritemx = lt_itemx
        return  = lt_return.

    " Type A (abandon) et E (erreur) font échouer l'affectation ; W, I et S sont informatifs.
    IF line_exists( lt_return[ type = 'E' ] ) OR line_exists( lt_return[ type = 'A' ] ).
      rs_result = VALUE #( success = abap_false
                           message = error_text( lt_return ) ).
    ELSE.
      rs_result = VALUE #( success = abap_true ).
    ENDIF.

  ENDMETHOD.


  METHOD error_text.

    LOOP AT it_return INTO DATA(ls_return) WHERE type = 'E' OR type = 'A'.
      IF rv_text IS INITIAL.
        rv_text = ls_return-message.
      ELSE.
        rv_text = |{ rv_text } { ls_return-message }|.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
