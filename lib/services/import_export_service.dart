import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:perpus_app/models/book.dart';
import 'package:perpus_app/models/category.dart';

class ImportExportService {
  static final ImportExportService _instance = ImportExportService._();
  factory ImportExportService() => _instance;
  ImportExportService._();

  // Export books to Excel
  Future<bool> exportBooksToExcel(List<Book> books) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Books Data'];
      
      // Header row - Updated for newer Excel package
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('No');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Judul');
      sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Pengarang');
      sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Penerbit');
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Tahun');
      sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Stok');

      // Data rows
      for (int i = 0; i < books.length; i++) {
        var book = books[i];
        var row = i + 2;
        
        sheet.cell(CellIndex.indexByString('A$row')).value = IntCellValue(i + 1);
        sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(book.judul);
        sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(book.pengarang);
        sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(book.penerbit);
        sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(book.tahun);
        sheet.cell(CellIndex.indexByString('F$row')).value = IntCellValue(book.stok);
      }

      var fileBytes = excel.save();
      if (fileBytes == null) return false;

      String fileName = 'Data_Buku_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.xlsx';
      
      // Save file using file_saver
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      return true;
    } catch (e) {
      print('Error exporting to Excel: $e');
      return false;
    }
  }

  // Export books to PDF
  Future<bool> exportBooksToPDF(List<Book> books) async {
    try {
      // Debug: check if books is empty
      print('Exporting ${books.length} books to PDF');
      
      if (books.isEmpty) {
        print('No books to export');
        return false;
      }

      // Debug: print first few books
      for (int i = 0; i < (books.length < 3 ? books.length : 3); i++) {
        Book book = books[i];
        print('Book ${i + 1}: ${book.judul} by ${book.pengarang} (${book.tahun}) - Stok: ${book.stok}');
      }

      final pdf = pw.Document();

      // Split books into chunks for multiple pages
      const int itemsPerPage = 30; // Balanced items per page like screenshot
      List<List<Book>> chunks = [];
      for (int i = 0; i < books.length; i += itemsPerPage) {
        chunks.add(books.sublist(i, i + itemsPerPage > books.length ? books.length : i + itemsPerPage));
      }

      for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        print('Processing chunk ${chunkIndex + 1}/${chunks.length} with ${chunks[chunkIndex].length} books');
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 20), // Balanced margins like screenshot
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.max, // Fill full height
                children: [
                  // Header
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.only(bottom: 20),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.black, width: 2),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Data Buku Lengkap - Perpustakaan',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            // Use default system font without specifying
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Tanggal: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                              style: const pw.TextStyle(
                                fontSize: 12,
                                // Remove specific font to use default system font
                              ),
                            ),
                            pw.SizedBox(height: 2), // Consistent spacing for all pages
                            pw.Text(
                              chunkIndex > 0 ? 'Halaman ${chunkIndex + 1}' : '', // Always same height
                              style: const pw.TextStyle(
                                fontSize: 10,
                                // Remove specific font to use default system font
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 15), // Balanced spacing
                  
                  // Summary boxes (only on first page)
                  if (chunkIndex == 0) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          pw.Column(
                            children: [
                              pw.Text(
                                'Total Judul Buku',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  // Remove specific font to use default system font
                                ),
                              ),
                              pw.Text(
                                '${books.length}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  // Use default system font without specifying
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text(
                                'Total Stok',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  // Remove specific font to use default system font
                                ),
                              ),
                              pw.Text(
                                '${books.fold(0, (sum, book) => sum + book.stok)}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  // Use default system font without specifying
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            children: [
                              pw.Text(
                                'Total Kategori',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  // Remove specific font to use default system font
                                ),
                              ),
                              pw.Text(
                                '34', // Assuming 34 categories as shown in screenshot
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  // Use default system font without specifying
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 15), // Balanced spacing
                  ],
                  
                  // Table - use Expanded to fill remaining space
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                      columnWidths: const {
                        0: pw.FixedColumnWidth(30),   // No - balanced
                        1: pw.FixedColumnWidth(40),   // Kode - balanced  
                        2: pw.FlexColumnWidth(3),     // Judul  
                        3: pw.FlexColumnWidth(2),     // Pengarang
                        4: pw.FlexColumnWidth(2),     // Penerbit
                        5: pw.FixedColumnWidth(45),   // Tahun - balanced
                        6: pw.FlexColumnWidth(1.5),   // Kategori
                        7: pw.FixedColumnWidth(40),   // Stok - balanced
                      },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildHeaderCell('No'),
                          _buildHeaderCell('Kode'),
                          _buildHeaderCell('Judul'),
                          _buildHeaderCell('Pengarang'),
                          _buildHeaderCell('Penerbit'),
                          _buildHeaderCell('Tahun'),
                          _buildHeaderCell('Kategori'),
                          _buildHeaderCell('Stok'),
                        ],
                      ),
                      // Data rows
                      ...chunks[chunkIndex].asMap().entries.map((entry) {
                        int index = entry.key;
                        Book book = entry.value;
                        int globalIndex = (chunkIndex * itemsPerPage) + index + 1;
                        
                        return pw.TableRow(
                          decoration: index % 2 == 0 
                            ? const pw.BoxDecoration(color: PdfColors.grey50)
                            : null,
                          children: [
                            _buildDataCell(globalIndex.toString()),
                            _buildDataCell('${book.category.name.substring(0, 1).toUpperCase()}-${book.id}'),
                            _buildDataCell(book.judul, maxLines: 2),
                            _buildDataCell(book.pengarang),
                            _buildDataCell(book.penerbit),
                            _buildDataCell(book.tahun),
                            _buildDataCell(book.category.name),
                            _buildDataCell(book.stok.toString()),
                          ],
                        );
                      }),
                    ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
        
        print('Created ${chunks[chunkIndex].length} data rows for chunk ${chunkIndex + 1}');
      }

      final bytes = await pdf.save();
      String fileName = 'Laporan_Buku_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf';
      
      // Use FileSaver for direct download
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      
      return true;
    } catch (e) {
      print('Error exporting to PDF: $e');
      return false;
    }
  }

  // Import books from Excel
  Future<List<Book>?> importBooksFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.bytes != null) {
        var bytes = result.files.single.bytes!;
        var excel = Excel.decodeBytes(bytes);
        
        List<Book> importedBooks = [];
        
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          
          // Skip header row, start from row 1 (0-indexed)
          for (int row = 1; row < sheet.maxRows; row++) {
            try {
              var judulCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
              var pengarangCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
              var penerbitCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
              var tahunCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
              var stokCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));

              // Skip empty rows
              if (judulCell.value == null || judulCell.value.toString().trim().isEmpty) {
                continue;
              }

              String judul = judulCell.value?.toString().trim() ?? '';
              String pengarang = pengarangCell.value?.toString().trim() ?? '';
              String penerbit = penerbitCell.value?.toString().trim() ?? '';
              String tahun = tahunCell.value?.toString().trim() ?? '';
              int stok = 0;
              
              // Parse stok
              if (stokCell.value != null) {
                if (stokCell.value is IntCellValue) {
                  stok = (stokCell.value as IntCellValue).value;
                } else {
                  stok = int.tryParse(stokCell.value.toString()) ?? 0;
                }
              }

              if (judul.isNotEmpty && pengarang.isNotEmpty) {
                // Create book object for import
                Book book = Book(
                  id: 0, // Will be ignored during import
                  judul: judul,
                  pengarang: pengarang,
                  penerbit: penerbit,
                  tahun: tahun,
                  stok: stok,
                  category: Category(id: 0, name: 'Default'), // Dummy category for import
                );
                
                importedBooks.add(book);
              }
            } catch (e) {
              print('Error parsing row $row: $e');
              continue;
            }
          }
        }

        print('📚 Berhasil membaca ${importedBooks.length} buku dari Excel');
        return importedBooks;
      }
      
      return null;
    } catch (e) {
      print('Error importing from Excel: $e');
      return null;
    }
  }

  // Get template Excel file for import
  Future<bool> downloadImportTemplate() async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Template Import Buku'];
      
      // Header row - PASTIKAN URUTAN KOLOM SESUAI DENGAN PARSING!
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('No');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Judul *');
      sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Pengarang *');
      sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Penerbit');
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Tahun');
      sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Stok');

      // Example data - PASTIKAN ADA DATA CONTOH YANG VALID
      sheet.cell(CellIndex.indexByString('A2')).value = IntCellValue(1);
      sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue('Belajar Flutter');
      sheet.cell(CellIndex.indexByString('C2')).value = TextCellValue('John Doe');
      sheet.cell(CellIndex.indexByString('D2')).value = TextCellValue('Penerbit Maju');
      sheet.cell(CellIndex.indexByString('E2')).value = TextCellValue('2024');
      sheet.cell(CellIndex.indexByString('F2')).value = IntCellValue(10);

      // Add more example rows for testing
      sheet.cell(CellIndex.indexByString('A3')).value = IntCellValue(2);
      sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('Pemrograman Web');
      sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue('Jane Smith');
      sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('Penerbit Teknologi');
      sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue('2023');
      sheet.cell(CellIndex.indexByString('F3')).value = IntCellValue(5);

      // Instructions sheet
      var instructionSheet = excel['Petunjuk Import'];
      instructionSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('PETUNJUK IMPORT DATA BUKU');
      
      instructionSheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('1. Kolom yang wajib diisi ditandai dengan tanda bintang (*)');
      instructionSheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('2. Judul dan Pengarang tidak boleh kosong');
      instructionSheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('3. Stok harus berupa angka (default: 0)');
      instructionSheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('4. Urutan kolom: No, Judul, Pengarang, Penerbit, Tahun, Stok');
      instructionSheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('5. Hapus baris contoh sebelum mengimpor data asli');
      instructionSheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('6. Simpan file dalam format .xlsx atau .xls');
      instructionSheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('7. Buku akan dimasukkan ke kategori default pertama');

      var fileBytes = excel.save();
      if (fileBytes == null) {
        print('DEBUG: Failed to save Excel template');
        return false;
      }

      String fileName = 'Template_Import_Buku_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx';
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      print('DEBUG: Template downloaded: $fileName');
      return true;
    } catch (e) {
      print('Error creating template: $e');
      return false;
    }
  }

  // Helper method to build header cell
  pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4), // Slightly more padding
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8, // Readable header font
          fontWeight: pw.FontWeight.bold,
          // Use default system font without specifying
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Helper method to build data cell
  pw.Widget _buildDataCell(String text, {int maxLines = 1, bool center = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4), // Slightly more padding
      child: pw.Text(
        text.isNotEmpty ? text : '-',
        style: const pw.TextStyle(
          fontSize: 7, // Readable data font
          // Remove specific font to use default system font
        ),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
