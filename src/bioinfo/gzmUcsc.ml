open GzmUtils
open GzmCore

type genome = [ `mm9 | `hg18 | `sacCer2 ]
let string_of_genome = function
    `mm9 -> "mm9"
  | `hg18 -> "hg18"
  | `sacCer2 -> "sacCer2"

let chromosome_sequences org =
  let org = string_of_genome org in 
  d0
    ("guizmin.bioinfo.ucsc.chromosome_sequences[1]", [ string "org" org ])
    (fun path ->
      bash [
	sp "mkdir -p %s" path;
	sp "cd %s" path ;
	sp "wget ftp://hgdownload.cse.ucsc.edu/goldenPath/%s/chromosomes/*" org ;
	"gunzip *.gz"
      ])

let genome_sequence org = 
  f1
    ("guizmin.bioinfo.ucsc.genome_sequence[1]", [])
    (fun (Dir gp) path ->
      bash [ sp "cat %s/{chr?.fa,chr??.fa,chr???.fa,chr????.fa} > %s" gp path ])
    (chromosome_sequences org)

let genome_2bit_sequence org = 
  let org = string_of_genome org in 
  f0
    ("guizmin.bioinfo.ucsc.genome_sequence[1]", [ string "org" org ])
    (fun path ->
      bash [
        sp "wget -O %s ftp://hgdownload.cse.ucsc.edu/goldenPath/%s/bigZips/%s.2bit" path org org
      ])

let fasta_of_bed org bed = 
  let seq2b = genome_2bit_sequence org in
  f2
    ("guizmin.bioinfo.ucsc.fasta_of_bed[1]", [])
    (fun (File seq2b) (File bed) path ->
      sh "twoBitToFa -bed=%s %s %s" bed seq2b path)
    seq2b bed




















