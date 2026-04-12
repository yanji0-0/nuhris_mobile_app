import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xzirvadcrgqnvrzhekmj.supabase.co', // ← dito yung URL mo
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6aXJ2YWRjcmdxbnZyemhla21qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5NDY0NDAsImV4cCI6MjA5MDUyMjQ0MH0.5AsrwSkQa2js6VPrupkzwsjH6jGXWEz4X0qE-rDDBbY', // ← dito mo ilalagay yung kinopy mo
  );

  runApp(const AppShell());
}