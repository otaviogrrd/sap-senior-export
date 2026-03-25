REPORT zhr_senior_exp_1055.

*-Types----------------------------------------------------------------
TYPES: BEGIN OF gy_file,
         numemp TYPE n LENGTH 4,
         tipcol TYPE numc1,
         numcad TYPE n LENGTH 9,
         datref TYPE c LENGTH 10,
         natetg TYPE c,
         nivetg TYPE numc1,
         areatu TYPE c LENGTH 50,
         aposeg TYPE c LENGTH 30,
         valbol TYPE p LENGTH 9 DECIMALS 2,
         preter TYPE c LENGTH 10,
         insens TYPE n LENGTH 8,
         ageint TYPE n LENGTH 8,
         empcoo TYPE n LENGTH 4,
         tipcoo TYPE numc1,
         numcoo TYPE n LENGTH 9,
         nomcoo TYPE c LENGTH 70,
         cpfcoo TYPE c LENGTH 14,
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

  lv_filename = p_dir && sy-datum && '_SENIOR_1055.csv'.

  SELECT pa0001~pernr,pa0001~bukrs,pa0001~persg,pa0001~persk,pa0001~plans,
         pa0008~lga01,pa0008~bet01,
         pa0016~ctedt,
         pa0168~bplan,
         pa0398~begda,pa0398~internshp_type,pa0398~educ_level,pa0398~educ_inst_cod,pa0398~int_agent_cod INTO TABLE @DATA(lt_dados)
   FROM pa0001
   INNER JOIN pa0008 ON pa0008~pernr EQ pa0001~pernr
   INNER JOIN pa0016 ON pa0016~pernr EQ pa0001~pernr
   INNER JOIN pa0168 ON pa0168~pernr EQ pa0001~pernr
   INNER JOIN pa0398 ON pa0398~pernr EQ pa0001~pernr
  WHERE pa0001~endda EQ '99991231'
    AND pa0001~persk EQ '50'
    AND pa0008~endda EQ '99991231'
    AND pa0008~lga01 EQ '0020'
    AND pa0016~endda EQ '99991231'
    AND pa0398~endda EQ '99991231'.

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

  " Data de Referência
  ASSIGN COMPONENT 'BEGDA' OF STRUCTURE us_dados TO <lf_value>.
  lv_dats = <lf_value>.
  PERFORM f_conv_date   IN PROGRAM zhr_export_senior USING lv_dats CHANGING lv_datopc.
  <lf_file>-datref = lv_datopc.

  " Natureza do Estágio
  ASSIGN COMPONENT 'INTERNSHP_TYPE' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-natetg = <lf_value>.

  " Nível do Estágio
  ASSIGN COMPONENT 'EDUC_LEVEL' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-nivetg = <lf_value>.

  " Área de atuação do estagiário
*  <lf_file>-areatu

  " Apólice de Seguro
  ASSIGN COMPONENT 'BPLAN' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-aposeg = <lf_value>.

  " Valor da Bolsa
  ASSIGN COMPONENT 'BET01' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-valbol = <lf_value>.

  " Data prevista para o término do estágio
  ASSIGN COMPONENT 'CTEDT' OF STRUCTURE us_dados TO <lf_value>.
  lv_dats = <lf_value>.
  PERFORM f_conv_date IN PROGRAM zhr_export_senior USING lv_dats CHANGING lv_datopc.
  <lf_file>-preter = lv_datopc.

  " Instituição de Ensino
  ASSIGN COMPONENT 'EDUC_INST_COD' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-insens = <lf_value>.

  " Agente de Integração
  ASSIGN COMPONENT 'INT_AGENT_COD' OF STRUCTURE us_dados TO <lf_value>.
  <lf_file>-ageint = <lf_value>.

  " Empresa do Supervisor
*  <lf_file>-empcoo

  " Tipo Supervisor
*  <lf_file>-tipcoo

  " Cadastro do Supervisor
*  <lf_file>-numcoo

  " Nome do Supervisor
*  <lf_file>-nomcoo

  " Número do CPF do Supervisor
*  <lf_file>-cpfcoo

ENDFORM.
