"! <p class="shorttext synchronized">Sources disponibles - implémentation de la requête</p>
"! Alimente l'entité personnalisée ZI_ResaSourceOption, c'est-à-dire le contenu de la pop-up.
"!
"! Le poste de demande d'achat est obligatoire en filtre : la classe lit ce poste pour en
"! déduire le besoin (division, article, quantité, unité, date), puis interroge
"! ZIF_RESA_SRC_PROVIDER. Aucune source n'est présélectionnée.
CLASS zcl_resa_src_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.

    TYPES tt_option TYPE STANDARD TABLE OF zi_resasourceoption WITH EMPTY KEY.

    "! Intervalles de sélection d'un filtre nommé, tels que transmis par le service.
    METHODS ranges_for
      IMPORTING it_ranges        TYPE if_rap_query_filter=>tt_name_range_pairs
                iv_name          TYPE string
      RETURNING VALUE(rt_ranges) TYPE if_rap_query_filter=>tt_range_option.

    "! Première valeur EQ d'un filtre nommé, ou valeur initiale.
    METHODS single_value
      IMPORTING it_ranges       TYPE if_rap_query_filter=>tt_name_range_pairs
                iv_name         TYPE string
      RETURNING VALUE(rv_value) TYPE string.

ENDCLASS.


CLASS zcl_resa_src_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    TRY.
        DATA(lt_ranges) = io_request->get_filter( )->get_as_ranges( ).

        DATA(lv_pur_req)  = single_value( it_ranges = lt_ranges
                                          iv_name   = 'PURCHASEREQUISITION' ).
        DATA(lv_pur_item) = single_value( it_ranges = lt_ranges
                                          iv_name   = 'PURCHASEREQUISITIONITEM' ).

        " Sans poste de DA, la liste des sources n'a pas de sens : le dire, plutôt que de
        " renvoyer un tableau vide que l'utilisateur lirait comme « aucune source disponible ».
        IF lv_pur_req IS INITIAL OR lv_pur_item IS INITIAL.
          RAISE EXCEPTION TYPE zcx_resa_src
            EXPORTING textid = zcx_resa_src=>contexte_incomplet.
        ENDIF.

        SELECT SINGLE Plant, Material, RequestedQuantity, BaseUnit, DeliveryDate
          FROM zi_resapurreqnosource
          WHERE PurchaseRequisition     = @lv_pur_req
            AND PurchaseRequisitionItem = @lv_pur_item
          INTO @DATA(ls_item).

        " Poste absent de la liste de travail : servi, converti ou clôturé entre-temps.
        IF sy-subrc <> 0.
          io_response->set_total_number_of_records( 0 ).
          io_response->set_data( VALUE tt_option( ) ).
          RETURN.
        ENDIF.

        DATA(lt_sources) = zcl_resa_src_provider=>get_instance( )->get_sources(
          VALUE #( plant         = ls_item-Plant
                   material      = ls_item-Material
                   quantity      = ls_item-RequestedQuantity
                   base_unit     = ls_item-BaseUnit
                   delivery_date = ls_item-DeliveryDate ) ).

        " Filtre « Type de source » de la boîte de dialogue, appliqué après l'appel :
        " le programme de détermination est interrogé une seule fois, sur le besoin complet.
        DATA(lr_type) = ranges_for( it_ranges = lt_ranges
                                    iv_name   = 'SOURCETYPE' ).
        IF lr_type IS NOT INITIAL.
          DELETE lt_sources WHERE source_type NOT IN lr_type.
        ENDIF.

        DATA lt_result TYPE tt_option.
        LOOP AT lt_sources INTO DATA(ls_source).
          APPEND VALUE #(
            purchaserequisition     = lv_pur_req
            purchaserequisitionitem = lv_pur_item
            sourcetype              = ls_source-source_type
            sourceid                = ls_source-source_id
            sourcename              = ls_source-source_name
            sourcetypetext          = SWITCH #( ls_source-source_type
                                                WHEN 'EDI'  THEN 'Fournisseur'
                                                WHEN 'WHSE' THEN 'Entrepôt'
                                                WHEN 'STOR' THEN 'Centre voisin'
                                                ELSE CONV string( ls_source-source_type ) )
            supplier                = ls_source-supplier
            purchasinginforecord    = ls_source-info_record
            purchasingorganization  = ls_source-purchasing_org
            supplyingplant          = ls_source-supplying_plant
            availability            = ls_source-availability
            availabilitytext        = SWITCH #( ls_source-availability
                                                WHEN 'A' THEN 'Disponible'
                                                WHEN 'B' THEN 'Partiellement disponible'
                                                WHEN 'C' THEN 'Non disponible'
                                                ELSE '' )
            availabilitycriticality = SWITCH #( ls_source-availability
                                                WHEN 'A' THEN 3
                                                WHEN 'B' THEN 2
                                                ELSE 1 )
            availablequantity       = ls_source-available_qty
            baseunit                = COND #( WHEN ls_source-base_unit IS INITIAL
                                              THEN ls_item-BaseUnit
                                              ELSE ls_source-base_unit )
            netprice                = ls_source-net_price
            currency                = ls_source-currency
            leadtimedays            = ls_source-lead_time_days
            sourcerank              = ls_source-source_rank ) TO lt_result.
        ENDLOOP.

        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( lt_result ) ).
        ENDIF.

        " Pagination : la pop-up demande une page à la fois.
        DATA(lo_paging) = io_request->get_paging( ).
        DATA(lv_offset) = lo_paging->get_offset( ).
        DATA(lv_page)   = lo_paging->get_page_size( ).

        IF lv_offset > 0.
          DELETE lt_result TO lv_offset.
        ENDIF.
        IF lv_page <> if_rap_query_paging=>page_size_unlimited
           AND lines( lt_result ) > lv_page.
          DELETE lt_result FROM lv_page + 1.
        ENDIF.

        io_response->set_data( lt_result ).

      CATCH zcx_resa_src INTO DATA(lo_error).
        " Remonter le message tel quel : l'acheteur doit savoir si la détermination a échoué.
        " ⚠️ À vérifier (relevé R6) : si cx_rap_query_provider n'accepte pas l'addition MESSAGE
        " dans le système, utiliser « EXPORTING textid = ... » et vérifier l'affichage à l'écran.
        RAISE EXCEPTION TYPE cx_rap_query_provider
          MESSAGE ID lo_error->if_t100_message~t100key-msgid
          NUMBER    lo_error->if_t100_message~t100key-msgno
          WITH      lo_error->mv_msgv1 lo_error->mv_msgv2.
    ENDTRY.

  ENDMETHOD.


  METHOD ranges_for.

    LOOP AT it_ranges INTO DATA(ls_range) WHERE name = iv_name.
      APPEND LINES OF ls_range-range TO rt_ranges.
    ENDLOOP.

  ENDMETHOD.


  METHOD single_value.

    LOOP AT it_ranges INTO DATA(ls_range) WHERE name = iv_name.
      LOOP AT ls_range-range INTO DATA(ls_option) WHERE option = 'EQ' AND sign = 'I'.
        rv_value = ls_option-low.
        RETURN.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
