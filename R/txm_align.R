utils::globalVariables(c(
  "ID", "."
))

#' Customized local BLAST
#'
#' Build and run a customized BLAST alignment using local command line BLAST and locally downloaded databases from
#' within RStudio. User defined inputs and specifications are used to build a BLAST command, which is
#' transferred to RStudio terminal. The output is formatted as BLASTn tabular output format 6.
#'
#' @name txm_align
#' @param input (Required) All input types accepted by \link[dada2]{getSequences}.
#' @param database_path,database_name (Required) Full path and name for a local BLAST
#'                                     database being used for alignment.
#' @param previous_run (Optional) Default NULL. Remove previously aligned sequences
#'                     (must contain valid IDs)
#' @param task (Optional) Default "megablast".
#' @param output_name (Optional) Default "Output" + System date.
#'                     Specify name of the output files.
#' @param threads (Optional) Default 1. Number of threads assigned to BLAST alignment.
#' @param accession_list (Optional) Default NULL. A list of accession IDs that will be
#'                        used to restrict the BLAST database (-seqidlist), which is highly recommended
#'                        for large databases such as "nt/nr". This can be obtained using
#'                        the \link[taxminer]{txm_accIDs} function provided within this
#'                        package. Further information regarding search limitations is
#'                        available on
#'                        \href{https://www.ncbi.nlm.nih.gov/books/NBK279673/}{BLAST command line user manual}
#' @param do_acc_check (Logical) Default FALSE. If an accession ID list is provided, BLASTDB v5 requires it to be
#'                      pre-processed (blastdb_aliastool) prior to being used for restricting the database.
#'                      Set this to TRUE is an unprocessed accession ID list is specified.
#' @param show (Logical) Default FALSE. Switch from console to terminal?
#' @param Run_Blast (Logical) Default TRUE. Set to FALSE if an existing comma-delimited alignment file is present
#'                   in the directory and the function should be utilized to process it.
#' @param qcvg (Optional) Default 98. Query coverage filtration in alignment as a percentage.
#' @param pctidt (Optional) Default 98. Percentage identity filtration in alignment as a percentage
#' @param max_out (Optional) Default 500. Maximum number of alignments ("-max_target_seqs"). This should be set much
#'                 higher when using large databases such as "nt/nr", especially when other restrictions are kept to a
#'                 minimum.
#' @export
#' @importFrom rlang .data

txm_align <- function(
input,
previous_run = NULL,
task = "megablast",
database_path = "~/Documents/NCBI_databases/16S",
database_name = "16S_ribosomal_RNA",
output_name = paste("Output", Sys.Date(), sep = ""),
threads = 1,
accession_list = "Bacteria_noEnv.seq",
do_acc_check = F,
show = F,
Run_Blast = T,
qcvg = 98,
pctidt = 98,
max_out = 500
) {

# Reset seqs to include all ASVs
seqs <- dada2::getSequences(input) %>%
  as.data.frame() %>%
  purrr::set_names("ASVs") %>%
  dplyr::mutate(ID = 1:nrow(.)) %>% # Add IDs to aid in filtration
  dplyr::select(.data$ID, .data$ASVs)

# Subset of ASVs that were not successfully annotated in the previous step
if (!is.null(previous_run)) {
  print("Removing IDs from previous run")
  ASVs <- seqs %>%
    dplyr::filter(!.data$ID %in% previous_run$ID) %>% # Get ids that were removed in the previous filtration
    dplyr::distinct(.data$ID, .keep_all = T)
  print(paste("Previous Run specified - ", nrow(ASVs), " of ", nrow(seqs),
              " will be aligned", sep = ""))
} else {
  ASVs <- seqs
  print(paste(nrow(ASVs), " of ", nrow(seqs), " will be aligned", sep = ""))
}

# Converting the ASVs to fasta format
FASTA_file <- ASVs %>%
  dplyr::mutate(ID = paste(">", ID, sep = "")) %>%
  as.list() %>%
  purrr::pmap(~ paste(.x, .y, sep = "\n")) %>%
  unlist()

readr::write_lines(FASTA_file, file = paste("FASTA_", output_name, ".fa", sep = ""))


if (Run_Blast == T) {

  # Moving file to database folder
  files_to_copy <- c(
    paste(database_path, "/taxdb.bti", sep = ""),
    paste(database_path, "/taxdb.btd", sep = "")
  )
  if (file.exists(files_to_copy[1])&file.exists(files_to_copy[2])) {
    file.copy(files_to_copy, to = ".", overwrite = T)
  } else {
    print("No taxdb files found in the databases folder. BLAST output will not contain species")
  }


  if (!is.null(accession_list)) {
    if (do_acc_check == T) {
      # Pre-processing accession numbers list
      Command <- "blastdb_aliastool"
      input_list <- paste("-seqid_file_in ", accession_list, sep = "")

      Terminal_command <- paste(Command,
                                input_list,
                                sep = " ")

      acc_check <- rstudioapi::terminalExecute(Terminal_command, show = show)

      # Keep R session busy until terminal command is completed
      while (is.null(rstudioapi::terminalExitCode(acc_check))) {
        Sys.sleep(0.1)
      }
      if (rstudioapi::terminalExitCode(acc_check) == 0) {
        print("Accession list check successful")
        # kill terminal
        rstudioapi::terminalKill(acc_check)
        accession_list <- paste(accession_list, ".bsl", sep = "")

      } else {
        stop(print(paste("Accession list check ran into an error - Code: ",
                         rstudioapi::terminalExitCode(acc_check),
                         " - Please check terminal for details")))
      }
    }
  }

  if (file.size(paste(output_name, ".fa", sep = "")) == 0) {
    stop(print("Empty query object provided"))
  }


  Shell_command <- paste("blastn -task ", task, sep = "")
  database <- paste("-db ", database_path, "/", database_name, sep = "")
  query <- paste("-query ", output_name, ".fa", sep = "")
  output <- paste("-out ", "Alignment_", output_name, ".csv", sep = "")
  parameters <- paste("-num_threads", threads, "-perc_identity", pctidt, sep = " ")
  accession_limit <- paste("-seqidlist", accession_list, sep = " ")
  output_format <- paste("-max_target_seqs", max_out,
                         "-outfmt '6 qacc sseqid staxids sscinames bitscore qcovs evalue pident'")

  Terminal_command <- paste(Shell_command,
                            database,
                            query,
                            output,
                            if (!is.null(accession_list)) {
                              accession_limit
                            },
                            parameters,
                            output_format,
                            sep = " ")

  Blast <- rstudioapi::terminalExecute(Terminal_command, show = show)
  print(paste("Running Blast - ", Terminal_command, sep = ""))
  # Keep R session busy until terminal command is completed
  while (is.null(rstudioapi::terminalExitCode(Blast))) {
    Sys.sleep(0.1)
  }

  if (rstudioapi::terminalExitCode(Blast) == 0) {
    print("Blast successful")
  } else {
    stop(print(paste("Blast ran into an error - Code: ", rstudioapi::terminalExitCode(Blast),
                     " - Please check terminal for details")))
  }

  # kill terminal
  rstudioapi::terminalKill(Blast)
}


# Read in annotated list
Blast_output <- readr::read_delim(paste(output_name, ".csv", sep = ""),
                           "\t", col_names = F,
                           col_types = readr::cols(X3 = readr::col_number())) %>%
  magrittr::set_colnames(c("ID", "SeqID", "TaxID", "Species", "bitscore",
                           "qcovs", "Evalue", "Pct")) %>%
  as.data.frame() %>%
  #mutate(Species = sub('^([^ ]+ [^ ]+).*', '\\1', Species)) %>%
  dplyr::mutate(SeqID = stringr::str_replace_all(.data$SeqID, pattern = "\\|",
                                                 replacement = ";")) %>%
  dplyr::mutate(AccID = sub(".*?;.*?;.*?;(.*?);.*", "\\1", .data$SeqID)) %>%
  dplyr::mutate(GiID = sub("gi;(.*?);.*", "\\1", .data$SeqID)) %>%
  dplyr::mutate(TaxID = as.numeric(stringr::str_extract(.data$TaxID, pattern = "^[^;]*"))) %>%
  dplyr::mutate(Species = stringr::str_extract(.data$Species, pattern = "^[^;]*"))
}
