REPORT zhr_senior_exp_1054.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         numemp TYPE n LENGTH 4,
         tipcol TYPE numc1,
         numcad TYPE n LENGTH 9,
         datadm TYPE c LENGTH 10,
         admeso TYPE numc1,
         indadm TYPE numc1,
         tinant TYPE numc1,
         cnpjan TYPE c LENGTH 15,
         admant TYPE c LENGTH 10,
         matant TYPE c LENGTH 30,
         onusce TYPE n LENGTH 2,
         catant TYPE n LENGTH 3,
         resonu TYPE c LENGTH 1,
         segdes TYPE numc1,
         cfjant TYPE c LENGTH 15,
       END OF gy_file.

DATA: gt_file TYPE TABLE OF gy_file.

*-Tela de Seleção -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_dir TYPE string LOWER CASE.
SELECTION-SCREEN END OF BLOCK blc1.

*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_dir.
  PERFORM zf_search_help_directory.

START-OF-SELECTION.

  IF p_dir IS INITIAL.
    MESSAGE 'Informe o diretorio local de destino.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*&---------------------------------------------------------------------*
*&      Form  ZF_SEARCH_HELP_DIRECTORY
*&---------------------------------------------------------------------*
FORM zf_search_help_directory.

  DATA lv_folder TYPE string.
  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF NOT lv_folder IS INITIAL.
    p_dir = lv_folder.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_NORMALIZAR_CAMINHOS
*&---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_dir ) - 1.

  IF p_dir IS NOT INITIAL.
    lv_last = p_dir+vl_strlen(1).
    IF lv_last <> '/' AND lv_last <> '\'.
      CONCATENATE p_dir '\' INTO p_dir.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_EXPORTAR_DADOS
*&---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA: lt_conv TYPE truxs_t_text_data.

  DATA: ls_data TYPE gy_file.

  DATA: lv_filename TYPE string,
        lv_header   TYPE string,
        lv_line     TYPE string.

  DATA: lv_erro TYPE flag.

  lv_filename = p_dir && sy-datum && '_SENIOR_1054.csv'.

  SELECT pa0000~pernr,pa0000~massn,pa0000~massg,
         pa0001~bukrs,pa0001~persg,
         pa0041~dar01,pa0041~dat01
   INTO TABLE @DATA(lt_dados)
   FROM pa0000
   INNER JOIN pa0001 ON pa0001~pernr EQ pa0000~pernr
   INNER JOIN pa0041 ON pa0041~pernr EQ pa0000~pernr
  WHERE pa0000~endda EQ '99991231'
    AND pa0001~endda EQ '99991231'
    AND pa0041~endda EQ '99991231'.

  LOOP AT lt_dados ASSIGNING FIELD-SYMBOL(<lf_dados>).
    PERFORM zf_process_registration USING <lf_dados>.
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

  PERFORM f_salvar_arquivo USING lv_filename CHANGING lt_conv.

  WRITE: / 'Arquivo gerado com sucesso:', lv_filename.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                      CHANGING pt_file TYPE truxs_t_text_data.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = pv_filename
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZF_PROCESS_REGISTRATION
*&---------------------------------------------------------------------*
FORM zf_process_registration USING us_dados TYPE any.

  DATA: lv_persg  TYPE persg,
        lv_tipcol TYPE c LENGTH 1,
        lv_dats   TYPE d,
        lv_datopc TYPE char10.

  APPEND INITIAL LINE TO gt_file ASSIGNING FIELD-SYMBOL(<lf_file>).

  " Código da Empresa
  ASSIGN COMPONENT 'BUKRS' OF STRUCTURE us_dados TO FIELD-SYMBOL(<lf_value>).
  <lf_file>-numemp = <lf_value>.

  " Tipo Colaborador
  ASSIGN COMPONENT 'PERSG' OF STRUCTURE us_dados TO <lf_value>.
  lv_persg = <lf_value>.
  PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior USING lv_persg CHANGING lv_tipcol.
  <lf_file>-tipcol = lv_tipcol.

  " Cadastro do Colaborador
  ASSIGN COMPONENT 'PERNR' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-numcad = <lf_value>.

  " Data de Admissão nesta Empresa
  ASSIGN COMPONENT 'DAR01' OF STRUCTURE us_dados TO <lf_value>.
  IF <lf_value> EQ '01'.
    ASSIGN COMPONENT 'DAT01' OF STRUCTURE us_dados TO <lf_value>.
    lv_dats = <lf_value>.
    PERFORM f_conv_date IN PROGRAM zhr_export_senior USING lv_dats CHANGING lv_datopc.
    <lf_file>-datadm = lv_datopc.
  ENDIF.

  " Tipo de admissão do trabalhador
  ASSIGN COMPONENT 'MASSN' OF STRUCTURE us_dados TO <lf_value>.
*  <lf_file>-admeso =

  " Indicativo de admissão
  ASSIGN COMPONENT 'MASSG' OF STRUCTURE us_dados TO <lf_value>.
*  <lf_file>-indadm =

  " Tipo de inscrição do empregador anterior
*  <lf_file>-tinant =

  " Número de inscrição do empregador anterior - Numérico
*  <lf_file>-cnpjan =

  " Data de início do vínculo trabalhista
*  <lf_file>-admant =

  " Matrícula do trabalhador na empresa que deu origem
*  <lf_file>-matant =

  " Informar foi cedido com ônus ou sem ônus para o empregador
*  <lf_file>-onusce =

  " Código da categoria eSocial de origem do trabalhador
*  <lf_file>-catant =

  " Ressarcimento Ônus
*  <lf_file>-resonu =

  " Informe se o colaborador está recebendo seguro
*  <lf_file>-segdes =

  " Número de inscrição do empregador anterior - Alfanumérico
*  <lf_file>-cfjant =


ENDFORM.
