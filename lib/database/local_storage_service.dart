
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _profileImageKey = 'profile_image_path';

  
  static Future<String?> saveProfileImage(String imagePath, String userId) async {
    try {
      
      final appDir = await getApplicationDocumentsDirectory();
      final profileImagesDir = Directory('${appDir.path}/profile_images');
      
      
      if (!await profileImagesDir.exists()) {
        await profileImagesDir.create(recursive: true);
      }
      
      
      final fileName = 'profile_$userId.jpg';
      final localImagePath = '${profileImagesDir.path}/$fileName';
      
    
      final imageFile = File(imagePath);
      final savedFile = await imageFile.copy(localImagePath);
      
     
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_profileImageKey}_$userId', savedFile.path);
      
      return savedFile.path;
    } catch (e) {
      print('Error al guardar imagen: $e');
      return null;
    }
  }


  static Future<String?> getProfileImagePath(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString('${_profileImageKey}_$userId');
      
      
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          return imagePath;
        } else {
          await prefs.remove('${_profileImageKey}_$userId');
        }
      }
      
      return null;
    } catch (e) {
      print('Error al obtener imagen: $e');
      return null;
    }
  }


  static Future<bool> deleteProfileImage(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString('${_profileImageKey}_$userId');
      
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
        await prefs.remove('${_profileImageKey}_$userId');
      }
      
      return true;
    } catch (e) {
      print('Error al eliminar imagen: $e');
      return false;
    }
  }
}