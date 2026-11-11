# Room creates generated database implementations through reflection.
# R8 full mode must retain their no-argument constructors for WorkManager startup.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
