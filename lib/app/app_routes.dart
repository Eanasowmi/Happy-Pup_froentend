import 'package:flutter/material.dart';
import '../features/age/age_prediction_screen.dart';
import '../features/bcs/body_condition_score_screen.dart';
import '../features/dog_tracker/bmi_calculator_screen.dart';
import '../features/history/growth_history_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/main_dashboard_screen.dart';
import '../features/home/dog_breed_scanner_screen.dart';
import '../features/skin_disease/dog_skin_disease_screen.dart';
import '../features/skin_disease/skin_disease_dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/dog_list_screen.dart';
import '../features/profile/add_edit_dog_screen.dart';
import '../features/profile/edit_profile_screen.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String agePrediction = '/age-prediction';
  static const String bcs = '/bcs';
  static const String bmi = '/bmi';
  static const String history = '/history';
  static const String skinDisease = '/skin-disease';
  static const String skinDiseaseScanner = '/skin-disease-scanner';
  static const String profile = '/profile';
  static const String breedScanner = '/breed-scanner';
  static const String dogList = '/dog-list';
  static const String addEditDog = '/add-edit-dog';
  static const String editProfile = '/edit-profile';

  static Map<String, WidgetBuilder> get routes {
    return {
      home: (context) => const HomeScreen(),
      dashboard: (context) => const MainDashboardScreen(),
      login: (context) => const LoginScreen(),
      signup: (context) => const SignupScreen(),
      agePrediction: (context) => const AgePredictionScreen(),
      bcs: (context) => const BodyConditionScoreScreen(),
      bmi: (context) => const BMICalculatorScreen(),
      history: (context) => const GrowthHistoryScreen(),
      skinDisease: (context) => const SkinDiseaseDashboardScreen(),
      skinDiseaseScanner: (context) => const DogSkinDiseasePredictorPage(),
      profile: (context) => const ProfileScreen(),
      breedScanner: (context) => const DogBreedScannerScreen(),
      dogList: (context) => const DogListScreen(),
      addEditDog: (context) => const AddEditDogScreen(),
      editProfile: (context) => EditProfileScreen(user: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>),
      forgotPassword: (context) => const ForgotPasswordScreen(),
    };
  }
}
