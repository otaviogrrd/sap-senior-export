REPORT zhr_senior_exp_1001.

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

  DATA:
    address       LIKE sadr,
    branch_record LIKE j_1bbranch,
    cgc_number    LIKE j_1bwfield-cgc_number.

  DATA:
    ls_adr2 TYPE adr2.

  gv_filename = sy-datum && '_SENIOR_1001.csv'.
  gv_header = 'NUMEMP;CODFIL;RAZSOC;NOMFIL;ENDFIL;'
    && 'CPLFIL;ENDNUM;CODBAI;CODEST;CODCID;'
    && 'DDITEL;DDDTEL;NUMTEL'.



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

    DATA(lv_numemp) = ||.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_branch>-bukrs
      CHANGING lv_numemp.

    gv_line =
          lv_numemp                    && ';'
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

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
