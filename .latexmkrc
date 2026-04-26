# .latexmkrc — configuração para compilação da raiz do projeto.
# Adiciona doc_pdf/ ao TEXINPUTS para que abntex2.cls (e ifes8.cls) sejam
# encontrados pelo pdflatex, mesmo quando invocado da raiz do workspace
# (ex.: VSCode LaTeX Workshop sem a flag -cd).
ensure_path('TEXINPUTS', './doc_pdf//');

$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=batchmode -synctex=1 %O %S';
@default_files = ('doc_pdf/lab1.tex');
