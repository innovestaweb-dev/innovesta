import 'package:supabase_flutter/supabase_flutter.dart';

class ContactService {
  static Future<bool> submitInquiry({
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'innovista-contact',
        body: data,
      );

      if (response.status != 200) {
        return false;
      }

      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
