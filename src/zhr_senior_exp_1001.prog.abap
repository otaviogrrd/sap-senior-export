REPORT zhr_senior_exp_1001.

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

  DATA:
    address       LIKE sadr,
    branch_record LIKE j_1bbranch,
    cgc_number    LIKE j_1bwfield-cgc_number.

  DATA:
    ls_adr2 TYPE adr2.

  gv_filename = sy-datum && '_SENIOR_1001.csv'.
  gv_header =
'NUMEMP;CODFIL;RAZSOC;NOMFIL;ENDFIL;CPLFIL;ENDNUM;CODBAI;CODEST;CODCID;DDITEL;DDDTEL;NUMTEL'.



  SELECT *
    INTO TABLE @DATA(tl_t001)
    FROM t001
   WHERE bukrs LIKE 'BR%'.

  IF sy-subrc NE 0.
    MESSAGE 'Nenhum dado encontrado na tabela T001.' TYPE 'E'.
  ENDIF.


  SELECT *
    INTO TABLE @DATA(tl_branch)
    FROM j_1bbranch
    FOR ALL ENTRIES IN @tl_t001
   WHERE bukrs = @tl_t001-bukrs.

  
  APPEND gv_header TO gt_file.


  LOOP AT tl_branch ASSIGNING FIELD-SYMBOL(<fs_branch>).


    CALL FUNCTION 'J_1B_BRANCH_READ'
      EXPORTING
        branch            = <fs_branch>-branch
        company           = <fs_branch>-bukrs
      IMPORTING
        address           = address
        branch_record     = branch_record
        cgc_number        = cgc_number
      EXCEPTIONS
        branch_not_found  = 1
        address_not_found = 2
        company_not_found = 3
        OTHERS            = 4.


    CLEAR ls_adr2.

    SELECT SINGLE *
      INTO ls_adr2
      FROM adr2
     WHERE addrnumber = address-adrnr.


    DATA(lv_ddi) = ''.
    DATA(lv_ddd) = ''.
    DATA(lv_tel) = ||.

    IF ls_adr2-tel_number IS NOT INITIAL.

      lv_tel = ls_adr2-tel_number.

      IF strlen( lv_tel ) > 4.
        lv_ddd = lv_tel+0(3).
        lv_tel = lv_tel+3.
      ENDIF.

    ENDIF.

    gv_line =
          <fs_branch>-bukrs            && ';'
        && <fs_branch>-branch          && ';'
        && branch_record-name          && ';'
        && branch_record-name          && ';'
        && address-stras               && ';'
        && address-strs2               && ';'
        && address-hausn               && ';'
        && ''                          && ';'
        && address-regio               && ';'
        && ''                          && ';'
        && lv_ddi                      && ';'
        && lv_ddd                      && ';'
        && lv_tel.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Arquivo gerado:', gv_filename.

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
