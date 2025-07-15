import 'package:perpus_app/models/peminjaman.dart';

class PeminjamanResponse {
  final List<Peminjaman> peminjamanList;
  final bool hasMore;

  PeminjamanResponse({required this.peminjamanList, required this.hasMore});
}