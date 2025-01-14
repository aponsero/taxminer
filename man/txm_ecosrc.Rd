% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/txm_ecosrc.R
\name{txm_ecosrc}
\alias{txm_ecosrc}
\title{Text mining and filtration}
\usage{
txm_ecosrc(
  input_table,
  filter_host = NA,
  filter_site = NA,
  filter_negate = NA,
  save_file_name = paste("TextmineR_", Sys.Date(), sep = ""),
  do_filter = T,
  Precomp_tbl = NA,
  Precomp_tbl_assign = paste("Dataset_", Sys.Date(), ".rds", sep = ""),
  savedata = T
)
}
\arguments{
\item{input_table}{(Required) Default NULL. Output table obtained from \link[taxminer]{txm_align}. Alternatively,
A data.frame with at least 3 columns
\itemize{
\item ID: sequence/hit ID numbers.
\item AccID: Accession IDs.
\item TaxID': taxonomic IDs.
}}

\item{filter_host}{(Optional) Default NA. Filter annotations by host}

\item{filter_site}{(Optional) Default NA. Filter annotations by body site or environment.}

\item{filter_negate}{(Optional) Default NA. Disregard annotations that contain these terms.}

\item{save_file_name}{(Optional) Default TextmineR + system date. Assign name to output file}

\item{do_filter}{(Logical) Default TRUE. Perform filtration using the word banks. If FALSE the output will
contain all accession IDs and the extracted information associated to them.}

\item{Precomp_tbl}{(Optional) Default NA. Specify the name of the pre-compiled database
present within the directory.}

\item{Precomp_tbl_assign}{(Optional) Default Dataset + system date. Name of a new compiled database
to be assigned}

\item{savedata}{(Logical) Default TRUE. Should a compiled database be saved to directory?}
}
\description{
Extract information from NCBI nucleotide and PubMed databases, attaching ecosystem specificity to each
accession ID. Different combinations of word banks are used to scan through this data and apply the filtration
criteria. The accession IDs are split into batches of 200, and \link[rentrez]{rentrez} is used to communicate with the NCBI databases.
}
