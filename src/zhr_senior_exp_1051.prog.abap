REPORT zhr_senior_exp_1051.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         codhor TYPE n LENGTH 4,
         seqmar TYPE n LENGTH 2,
         usobat TYPE n LENGTH 2,
         horbat TYPE t,
       END OF gy_file.

DATA: gt_file TYPE TABLE OF gy_file.

*-Tela de Sele??o -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_locl  TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE DEFAULT '/usr/sap/tmp/'.
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

  DATA: lt_conv TYPE truxs_t_text_data.

  DATA: ls_data TYPE gy_file.

  DATA: lv_filename TYPE string,
        lv_header   TYPE string.

  lv_filename = sy-datum && '_SENIOR_1051.csv'.
  
   " n?o tem nada
*  LOOP AT lt_dados ASSIGNING FIELD-SYMBOL(<lf_dados>).
*    PERFORM zf_process_registration USING <lf_dados>.
*  ENDLOOP.

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
FORM zf_process_registration USING us_dados TYPE any.

  APPEND INITIAL LINE TO gt_file ASSIGNING FIELD-SYMBOL(<lf_file>).

  " C?digo do Hor?rio
*  ASSIGN COMPONENT ' ' OF STRUCTURE us_dados
*    TO FIELD-SYMBOL(<lf_value>).
*<lf_file>-CODHOR = <lf_value>.

  " Sequ?ncia da Marca??o
*<lf_file>-SEQMAR

  " Uso da Marca??o
*<lf_file>-USOBAT

  " Hora da Marca??o
*<lf_file>-HORBAT

ENDFORM.
