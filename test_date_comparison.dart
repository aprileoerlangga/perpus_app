void main() {
  // Simulasi masalah yang Anda laporkan
  // Tanggal hari ini: 21 Juli 2025
  // Tanggal batas kembali: 25 Juli 2025
  // Seharusnya: BELUM terlambat (false)
  
  print('=== TEST DATE COMPARISON ===');
  
  // Simulasi tanggal hari ini
  final today = DateTime(2025, 7, 21); // 21 Juli 2025
  print('Today: ${today.toString()}');
  
  // Simulasi berbagai format tanggal dari API
  List<String> testDueDates = [
    '2025-07-25', // Format YYYY-MM-DD
    '25-07-2025', // Format DD-MM-YYYY  
    '2025-07-25T00:00:00.000Z', // Format ISO dengan timezone
    '2025-07-25 00:00:00', // Format dengan jam
  ];
  
  for (String dueDateStr in testDueDates) {
    print('\n--- Testing: "$dueDateStr" ---');
    
    try {
      DateTime dueDate;
      
      // Parse dengan logika yang sama seperti di aplikasi
      if (dueDateStr.contains('-') && dueDateStr.length >= 8) {
        List<String> parts = dueDateStr.split('-');
        if (parts.length >= 3) {
          // Clean up parts (remove time if exists)
          String yearPart = parts[0];
          String monthPart = parts[1];
          String dayPart = parts[2].split('T')[0].split(' ')[0]; // Remove time part
          
          if (yearPart.length == 4) {
            // Format YYYY-MM-DD
            dueDate = DateTime(int.parse(yearPart), int.parse(monthPart), int.parse(dayPart));
            print('Parsed as YYYY-MM-DD format');
          } else if (dayPart.length == 4) {
            // Format DD-MM-YYYY
            dueDate = DateTime(int.parse(dayPart), int.parse(monthPart), int.parse(yearPart));
            print('Parsed as DD-MM-YYYY format');
          } else {
            // Fallback
            dueDate = DateTime.parse(dueDateStr);
            print('Fallback to DateTime.parse');
          }
        } else {
          dueDate = DateTime.parse(dueDateStr);
        }
      } else {
        dueDate = DateTime.parse(dueDateStr);
      }
      
      // Normalize to date only
      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
      
      print('Due date: ${dueDateOnly.toString()}');
      
      // Test comparison
      bool isOverdue = today.isAfter(dueDateOnly);
      int daysDiff = today.difference(dueDateOnly).inDays;
      
      print('today.isAfter(dueDate): $isOverdue');
      print('Days difference: $daysDiff');
      print('Result: ${isOverdue ? "TERLAMBAT" : "BELUM TERLAMBAT"}');
      
      // Expected result
      if (dueDateStr.contains('25') && dueDateStr.contains('07') && dueDateStr.contains('2025')) {
        bool shouldBeLate = false; // 21 Juli < 25 Juli, jadi belum terlambat
        if (isOverdue == shouldBeLate) {
          print('✅ CORRECT: Book should ${shouldBeLate ? "be late" : "NOT be late"}');
        } else {
          print('❌ ERROR: Book should ${shouldBeLate ? "be late" : "NOT be late"} but got ${isOverdue ? "late" : "not late"}');
        }
      }
      
    } catch (e) {
      print('ERROR parsing: $e');
    }
  }
  
  print('\n=== MANUAL COMPARISON TEST ===');
  final july21 = DateTime(2025, 7, 21);
  final july25 = DateTime(2025, 7, 25);
  
  print('July 21: ${july21.toString()}');
  print('July 25: ${july25.toString()}');
  print('July 21 > July 25: ${july21.isAfter(july25)}'); // Should be false
  print('July 25 > July 21: ${july25.isAfter(july21)}'); // Should be true
  print('Days difference (21-25): ${july21.difference(july25).inDays}'); // Should be negative
  
  print('\n=== END TEST ===');
}
