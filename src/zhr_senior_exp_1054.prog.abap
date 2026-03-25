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

*-Tela de Sele??o -----------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK blc1 WITH FRAME TITLE text-001.
PARAMETERS: p_locl  TYPE string LOWER CASE,
            p_serv TYPE sapb-sappfad DEFAULT '/usr/sap/tmp/'.
SELECTION-SCREEN END OF BLOCK blc1.

*-Evento antes do processamento ---------------------------------------
AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior CHANGING p_serv.

START-OF-SELECTION.

  IF p_locl IS INITIAL AND p_serv IS INITIAL.
    MESSAGE 'Informe o destino local ou no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

FORM f_selecionar_arquivo.

  DATA lv_folder TYPE string.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_folder IS NOT INITIAL.
    p_locl = lv_folder.
  ENDIF.

ENDFORM.

FORM zf_search_help_directory.

  DATA lv_serverfile TYPE string.

  CALL FUNCTION '/SAPDMC/LSM_F4_SERVER_FILE'
    IMPORTING
      serverfile       = lv_serverfile
    EXCEPTIONS
      canceled_by_user = 1
      OTHERS           = 2.

  IF NOT lv_serverfile IS INITIAL.
    p_serv = lv_serverfile.
  ENDIF.

ENDFORM.

FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_locl IS NOT INITIAL.
    vl_strlen = strlen( p_locl ) - 1.
    IF vl_strlen >= 0.
      lv_last = p_locl+vl_strlen(1).
      IF lv_last <> '/' AND lv_last <> '\'.
        CONCATENATE p_locl '\' INTO p_locl.
      ENDIF.
    ENDIF.
  ENDIF.

  vl_strlen = strlen( p_serv ) - 1.
  IF p_serv IS NOT INITIAL AND vl_strlen >= 0.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/' AND lv_last <> '\'.
      CONCATENATE p_serv '/' INTO p_serv.
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

  IF p_serv IS NOT INITIAL.
    lv_filename = p_serv && sy-datum && '_SENIOR_1054.csv'.
  ELSE.
    lv_filename = p_locl && sy-datum && '_SENIOR_1054.csv'.
  ENDIF.
  
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

  IF p_serv IS NOT INITIAL.
    OPEN DATASET lv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
    IF sy-subrc <> 0.
      MESSAGE |Erro abrindo arquivo { lv_filename }| TYPE 'E'.
    ENDIF.

    LOOP AT lt_conv INTO DATA(ls_conv).
      TRANSFER ls_conv TO lv_filename.
      IF sy-subrc NE 0.
        lv_erro = abap_true. EXIT.
      ENDIF.
    ENDLOOP.
    CLOSE DATASET lv_filename.

    IF lv_erro IS NOT INITIAL.
      MESSAGE 'Erro ao gerar arquivo' TYPE 'E'.
    ELSE.
      WRITE: / 'Arquivo gerado com sucesso:', lv_filename.
    ENDIF.
  ELSE.
    CALL FUNCTION 'GUI_DOWNLOAD'
      EXPORTING
        filename = lv_filename
        filetype = 'ASC'
      TABLES
        data_tab = lt_conv
      EXCEPTIONS
        OTHERS   = 1.

    IF sy-subrc <> 0.
      MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
    ENDIF.

    WRITE: / 'Arquivo gerado com sucesso:', lv_filename.
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

  " C?digo da Empresa
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

  " Data de Admiss?o nesta Empresa
  ASSIGN COMPONENT 'DAR01' OF STRUCTURE us_dados TO <lf_value>.
  IF <lf_value> EQ '01'.
    ASSIGN COMPONENT 'DAT01' OF STRUCTURE us_dados TO <lf_value>.
    lv_dats = <lf_value>.
    PERFORM f_conv_date IN PROGRAM zhr_export_senior USING lv_dats CHANGING lv_datopc.
    <lf_file>-datadm = lv_datopc.
  ENDIF.

  " Tipo de admiss?o do trabalhador
  ASSIGN COMPONENT 'MASSN' OF STRUCTURE us_dados TO <lf_value>.
*  <lf_file>-admeso =

  " Indicativo de admiss?o
  ASSIGN COMPONENT 'MASSG' OF STRUCTURE us_dados TO <lf_value>.
*  <lf_file>-indadm =

  " Tipo de inscri??o do empregador anterior
*  <lf_file>-tinant =

  " N?mero de inscri??o do empregador anterior - Num?rico
*  <lf_file>-cnpjan =

  " Data de in?cio do v?nculo trabalhista
*  <lf_file>-admant =

  " Matr?cula do trabalhador na empresa que deu origem
*  <lf_file>-matant =

  " Informar foi cedido com ?nus ou sem ?nus para o empregador
*  <lf_file>-onusce =

  " C?digo da categoria eSocial de origem do trabalhador
*  <lf_file>-catant =

  " Ressarcimento ?nus
*  <lf_file>-resonu =

  " Informe se o colaborador est? recebendo seguro
*  <lf_file>-segdes =

  " N?mero de inscri??o do empregador anterior - Alfanum?rico
*  <lf_file>-cfjant =


ENDFORM.