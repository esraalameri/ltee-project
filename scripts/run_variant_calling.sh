set -euo pipefail

min_depth=${1:-2}   # vcfutils.pl varFilter -d (2 is its default)
out=${2:-results}   # all results go below this folder

genome=data/processed/reference/ecoli_rel606.fasta
mkdir -p data/processed/reference "$out/sam" "$out/bam" "$out/bcf" "$out/vcf" "$out/stats"

if [ ! -s "$genome" ]; then
    gunzip -c data/raw/reference/ecoli_rel606.fasta.gz > "$genome"
fi
bwa index "$genome"

for fq1 in data/raw/fastq/*_1.trim.sub.fastq; do
    base=$(basename "$fq1" _1.trim.sub.fastq)
    echo "working on sample $base"

    fq2=data/raw/fastq/${base}_2.trim.sub.fastq
    sam=$out/sam/${base}.aligned.sam
    bam=$out/bam/${base}.aligned.bam
    sorted_bam=$out/bam/${base}.aligned.sorted.bam
    raw_bcf=$out/bcf/${base}_raw.bcf
    variants=$out/bcf/${base}_variants.vcf
    final_variants=$out/vcf/${base}_final_variants.vcf

    bwa mem "$genome" "$fq1" "$fq2" > "$sam"
    samtools view -S -b "$sam" > "$bam"
    samtools sort -o "$sorted_bam" "$bam"
    samtools index "$sorted_bam"
    samtools flagstat "$sorted_bam" > "$out/stats/${base}.flagstat.txt"
    bcftools mpileup -O b -o "$raw_bcf" -f "$genome" "$sorted_bam"
    bcftools call --ploidy 1 -m -v -o "$variants" "$raw_bcf"
    vcfutils.pl varFilter -d "$min_depth" "$variants" > "$final_variants"
    bcftools stats "$final_variants" > "$out/stats/${base}.bcftools-stats.txt"
done

echo "done: final variants in $out/vcf/"
