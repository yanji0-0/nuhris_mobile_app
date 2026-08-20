class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xzirvadcrgqnvrzhekmj.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6aXJ2YWRjcmdxbnZyemhla21qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5NDY0NDAsImV4cCI6MjA5MDUyMjQ0MH0.5AsrwSkQa2js6VPrupkzwsjH6jGXWEz4X0qE-rDDBbY',
  );

  static const String laravelBaseUrl = String.fromEnvironment(
    'LARAVEL_BASE_URL',
    defaultValue: '',
  );
}
