import 'package:intl/intl.dart'; 

formatDate(String date) {
  String _formattedDate = DateFormat('dd/MM/yyyy H:m:s').format(new DateTime.fromMillisecondsSinceEpoch(int.parse(date)));
  return _formattedDate;
}