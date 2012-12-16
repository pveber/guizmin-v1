open GzmCore

type bigWig
type wig

type genome = [ `mm9 | `hg18 | `hg19 | `sacCer2 ]

val chromosome_sequences : genome -> [`ucsc_chromosome_sequences] dir
val genome_sequence : [< genome] -> Fasta.file
val genome_2bit_sequence : genome -> [`ucsc_2bit] file

val wg_encode_crg_mappability_36  : [`mm9 | `hg18 | `hg19] -> bigWig file
val wg_encode_crg_mappability_40  : [`mm9 | `hg18 | `hg19] -> bigWig file
val wg_encode_crg_mappability_50  : [`mm9 | `hg18 | `hg19] -> bigWig file
val wg_encode_crg_mappability_75  : [`mm9 | `hg18 | `hg19] -> bigWig file
val wg_encode_crg_mappability_100 : [`mm9 | `hg18 | `hg19] -> bigWig file

val fasta_of_bed : genome -> 'a Bed.file -> Fasta.file

val wig_of_bigWig : bigWig file -> wig file



















