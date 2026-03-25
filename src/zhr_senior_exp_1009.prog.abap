REPORT zhr_export_senior_1009.

PARAMETERS: p_file TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f_selecionar_arquivo.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1009.csv'.

  gv_header = 'CODSIN;NOMSIN;SIGSIN;MESDIS;ENTALF;NUMCGC;ENDRUA;ENDNUM;ENDCPL;CODCID;ENDCEP;CODBAI;CODENT;CFJCGC'.

*---------------------------------------------------------------------*
* SeleÃ§Ã£o sindicatos
*---------------------------------------------------------------------*

  SELECT
    t521b~emfsl,   " CÃ³digo sindicato
    t521b~etext,   " Nome
    t521b~stras,
    t521b~ort01,
    t521b~pstlz,
    t7br1b~basmo,
    t7br1b~sindi,
    t7br1b~uncgc

  INTO TABLE @DATA(gt_sind)

  FROM t521b AS t521b

  LEFT JOIN t7br1b
    ON t7br1b~sindi = t521b~emfsl.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_sigla  TYPE string,
    lv_mesdis TYPE c LENGTH 2,
    lv_cnpj   TYPE string,
    lv_cnpj_a TYPE string,
    lv_codent TYPE string.

  LOOP AT gt_sind ASSIGNING FIELD-SYMBOL(<fs_sind>).

*---------------------------------------------------------------------*
* SIGLA (gerar se nÃ£o existir)
*---------------------------------------------------------------------*

    lv_sigla = ''.

    IF lv_sigla IS INITIAL.

      DATA(lt_words) = VALUE stringtab( ).
      SPLIT <fs_sind>-etext AT space INTO TABLE lt_words.

      LOOP AT lt_words INTO DATA(lv_word).
        lv_sigla = lv_sigla && lv_word+0(1).
      ENDLOOP.

    ENDIF.

*---------------------------------------------------------------------*
* MESDIS (LMesAno)
*---------------------------------------------------------------------*

    PERFORM f_conv_mes IN PROGRAM zhr_export_senior
      USING <fs_sind>-basmo
      CHANGING lv_mesdis.

*---------------------------------------------------------------------*
* CNPJ numÃ©rico (NUMCGC)
*---------------------------------------------------------------------*

    lv_cnpj = <fs_sind>-uncgc.

    REPLACE ALL OCCURRENCES OF '.' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '/' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '-' IN lv_cnpj WITH ''.

*---------------------------------------------------------------------*
* CNPJ alfanumÃ©rico (CFJCGC)
*---------------------------------------------------------------------*

    lv_cnpj_a = lv_cnpj.

*---------------------------------------------------------------------*
* CODENT (atÃ© 12 posiÃ§Ãµes)
*---------------------------------------------------------------------*

    lv_codent = <fs_sind>-sindi.

    IF strlen( lv_codent ) > 12.
      lv_codent = lv_codent+0(12).
    ENDIF.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_sind>-emfsl    && ';' && " CODSIN
      <fs_sind>-etext    && ';' && " NOMSIN
      lv_sigla           && ';' && " SIGSIN
      lv_mesdis          && ';' && " MESDIS
      <fs_sind>-sindi    && ';' && " ENTALF
      lv_cnpj            && ';' && " NUMCGC
      <fs_sind>-stras    && ';' && " ENDRUA
      ''                 && ';' && " ENDNUM (nÃ£o separado no SAP)
      ''                 && ';' && " ENDCPL
      <fs_sind>-ort01    && ';' && " CODCID
      <fs_sind>-pstlz    && ';' && " ENDCEP
      ''                 && ';' && " CODBAI
      lv_codent          && ';' && " CODENT
      lv_cnpj_a.                    " CFJCGC

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      default_extension = 'csv'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_fullpath IS NOT INITIAL.
    p_file = lv_fullpath.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_filename TYPE string,
    lv_path     TYPE string,
    lv_fullpath TYPE string.

  lv_fullpath = p_file.

  IF lv_fullpath IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>file_save_dialog
      EXPORTING
        default_extension = 'csv'
        default_file_name = pv_filename
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_fullpath IS INITIAL.
      MESSAGE 'Selecao de arquivo cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_fullpath
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.

  p_file = lv_fullpath.

ENDFORM.
