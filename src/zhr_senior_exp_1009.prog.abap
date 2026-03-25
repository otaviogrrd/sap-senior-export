REPORT zhr_senior_exp_1009.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

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

  gv_header = 'CODSIN;NOMSIN;SIGSIN;MESDIS;ENTALF;NUMCGC;ENDRUA;'
  && 'ENDNUM;ENDCPL;CODCID;ENDCEP;CODBAI;CODENT;CFJCGC'.

*---------------------------------------------------------------------*
* Sele??o sindicatos
*---------------------------------------------------------------------*

  SELECT
    t521b~emfsl,   " C?digo sindicato
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
* SIGLA (gerar se n?o existir)
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
* CNPJ num?rico (NUMCGC)
*---------------------------------------------------------------------*

    lv_cnpj = <fs_sind>-uncgc.

    REPLACE ALL OCCURRENCES OF '.' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '/' IN lv_cnpj WITH ''.
    REPLACE ALL OCCURRENCES OF '-' IN lv_cnpj WITH ''.

*---------------------------------------------------------------------*
* CNPJ alfanum?rico (CFJCGC)
*---------------------------------------------------------------------*

    lv_cnpj_a = lv_cnpj.

*---------------------------------------------------------------------*
* CODENT (at? 12 posi??es)
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
      ''                 && ';' && " ENDNUM (n?o separado no SAP)
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

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_folder   TYPE string,
    lv_server   TYPE string,
    lv_fullpath TYPE string,
    lv_line     TYPE string.
  DATA:
    lv_last TYPE c LENGTH 1,
    lv_len  TYPE i.

  lv_server = p_serv.

  IF lv_server IS NOT INITIAL.
    lv_len = strlen( lv_server ) - 1.
    IF lv_len >= 0.
      lv_last = lv_server+lv_len(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        CONCATENATE lv_server '/' INTO lv_server.
      ENDIF.
    ENDIF.

    CONCATENATE lv_server pv_filename INTO lv_fullpath.

    OPEN DATASET lv_fullpath FOR OUTPUT
      IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
    IF sy-subrc <> 0.
      MESSAGE 'Erro ao salvar arquivo no servidor.' TYPE 'E'.
    ENDIF.

    LOOP AT pt_file INTO lv_line.
      TRANSFER lv_line TO lv_fullpath.
    ENDLOOP.

    CLOSE DATASET lv_fullpath.
    p_serv = lv_server.
    RETURN.
  ENDIF.

  lv_folder = p_locl.

  IF lv_folder IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>directory_browse
      CHANGING
        selected_folder      = lv_folder
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_folder IS INITIAL.
      MESSAGE 'Selecao de diretorio cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  lv_len = strlen( lv_folder ) - 1.
  IF lv_len >= 0.
    lv_last = lv_folder+lv_len(1).
    IF lv_last <> '\' AND lv_last <> '/'.
      CONCATENATE lv_folder '\' INTO lv_folder.
    ENDIF.
  ENDIF.

  CONCATENATE lv_folder pv_filename INTO lv_fullpath.

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

  p_locl = lv_folder.

ENDFORM.
