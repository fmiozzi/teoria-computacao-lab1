# .latexmkrc — configuração para compilação dentro de doc_pdf/.
# Garante que o diretório corrente (doc_pdf/) esteja no TEXINPUTS para
# que abntex2.cls seja encontrado por qualquer ferramenta LaTeX que
# use latexmk com -cd (ex.: VSCode LaTeX Workshop padrão).
ensure_path('TEXINPUTS', './');

$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=batchmode -synctex=1 %O %S';
