REPORT zhr_senior_exp_1053.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         codesc TYPE c LENGTH 4,
         seqreg TYPE c LENGTH 4,
         codhor TYPE c LENGTH 8,
         horbu1 TYPE c LENGTH 4,
         horbu2 TYPE c LENGTH 4,
         horbu3 TYPE c LENGTH 4,
         horbu4 TYPE c LENGTH 4,
         horbu5 TYPE c LENGTH 4,
         hordup TYPE c LENGTH 4,
       END OF gy_file.

DATA: gt_file TYPE TABLE OF gy_file.

TYPES: gty_t551a TYPE STANDARD TABLE OF t551a.

*-Tela de Sele??o -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_locl  TYPE string LOWER CASE,
            p_serv TYPE sapb-sappfad DEFAULT '/usr/sap/tmp/'.
SELECTION-SCREEN END OF BLOCK blc1.

*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  IF p_locl IS INITIAL AND p_serv IS INITIAL.
    MESSAGE 'Informe o destino local ou no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_exportar_dados.
*&---------------------------------------------------------------------*
*&      Form  F_EXPORTAR_DADOS
*&---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA: lr_zmodn     TYPE rsis_t_range,
        lr_zmodn_aux TYPE rsis_t_range.

  DATA: lv_index1 TYPE i,
        lv_index2 TYPE i.

  DATA: lt_conv TYPE truxs_t_text_data.

  DATA: ls_data TYPE gy_file.

  DATA: lv_filename TYPE string,
        lv_header   TYPE string.

  lv_filename = sy-datum && '_SENIOR_1053.csv'.
  
  SELECT schkz,zmodn INTO TABLE @DATA(lt_t508a)
    FROM t508a
   WHERE mofid EQ 'BR'
     AND mosid EQ '37'.
  SORT lt_t508a BY zmodn.
  DELETE ADJACENT DUPLICATES FROM lt_t508a COMPARING zmodn.

  LOOP AT lt_t508a ASSIGNING FIELD-SYMBOL(<lf_t508a>).
    APPEND VALUE #( option = 'EQ'
                    sign   = 'I'
                    low    = <lf_t508a>-zmodn ) TO lr_zmodn.
  ENDLOOP.

  SORT lr_zmodn BY low.
  DELETE ADJACENT DUPLICATES FROM lr_zmodn COMPARING low.
  lv_index2 = 1.
  DO.
    lv_index1 = lv_index2.
    lv_index2 = lv_index1 + 32000.
    APPEND LINES OF lr_zmodn FROM lv_index1 TO lv_index2
      TO lr_zmodn_aux.
    IF lr_zmodn_aux[] IS INITIAL. EXIT. ENDIF.
    SELECT * APPENDING TABLE @DATA(lt_t551a)
      FROM t551a
     WHERE motpr EQ '37'
       AND zmodn IN @lr_zmodn_aux.
    FREE lr_zmodn_aux[].
  ENDDO.
  SORT lt_t551a BY zmodn.

  LOOP AT lt_t508a ASSIGNING <lf_t508a>.
    PERFORM zf_process_registration USING <lf_t508a> lt_t551a.
  ENDLOOP.

  CALL FUNCTION 'SAP_CONVERT_TO_CSV_FORMAT'
    EXPORTING
      i_field_seperator    = ';'
    TABLES
      i_tab_sap_data       = gt_file
    CHANGING
      i_tab_converted_data = lt_conv
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.

  " Header
  DATA(lo_typedescr) = cl_abap_typedescr=>describe_by_data( ls_data ).
  IF lo_typedescr->kind = cl_abap_typedescr=>kind_struct.
    DATA(lo_structdescr) = CAST cl_abap_structdescr( lo_typedescr ).
    DATA(lt_components) = lo_structdescr->components.
    LOOP AT lt_components ASSIGNING FIELD-SYMBOL(<lf_component>).
      lv_header = |{ lv_header }| & |;|  & |{ <lf_component>-name }|.
    ENDLOOP.
    lv_header = lv_header+1.
  ENDIF.
  INSERT lv_header INTO lt_conv INDEX 1.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior
    USING lv_filename
    CHANGING lt_conv p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', lv_filename.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESS_REGISTRATION
*&---------------------------------------------------------------------*
FORM zf_process_registration USING us_t508a TYPE any
                                   ut_t551a TYPE gty_t551a.

  DATA: lv_zmodn TYPE dzmodn,
        lv_cont  TYPE numc1.

  ASSIGN COMPONENT 'ZMODN' OF STRUCTURE us_t508a
    TO FIELD-SYMBOL(<lf_value>).
  lv_zmodn = <lf_value>.
  LOOP AT ut_t551a ASSIGNING FIELD-SYMBOL(<lf_t551a>)
    WHERE zmodn EQ lv_zmodn.

    DO 7 TIMES.
      ADD 1 TO lv_cont.
      DATA(lv_tprg) = |<LF_T551A>-TPRG| & |{ lv_cont }|.
      ASSIGN (lv_tprg) TO FIELD-SYMBOL(<lf_tprg>).
      CHECK <lf_tprg> IS ASSIGNED.
      CHECK <lf_tprg> IS NOT INITIAL.

      APPEND INITIAL LINE TO gt_file ASSIGNING FIELD-SYMBOL(<lf_file>).

      " C?digo da Escala
      <lf_file>-codesc = lv_zmodn.

      " Sequ?ncia do Registro
      <lf_file>-seqreg = <lf_tprg>.

      " C?digo do Hor?rio Base
      ASSIGN COMPONENT 'SCHKZ' OF STRUCTURE us_t508a TO <lf_value>.
      <lf_file>-codhor = <lf_value>.

      " C?digo do Hor?rio Opcional 1
*<lf_file>-HORBU1

      " C?digo do Hor?rio Opcional 2
*<lf_file>-HORBU2

      " C?digo do Hor?rio Opcional 3
*<lf_file>-HORBU3

      " C?digo do Hor?rio Opcional 4
*<lf_file>-HORBU4

      " C?digo do Hor?rio Opcional 5
*<lf_file>-HORBU5

      " C?digo do Hor?rio de Turno Duplo
*<lf_file>-HORDUP
    ENDDO.

  ENDLOOP.

ENDFORM.
