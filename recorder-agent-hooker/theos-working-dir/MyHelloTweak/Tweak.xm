#import <stdio.h>
#import <time.h>

// Define the hard path for the log file in a simple location
#define LOG_FILE_PATH "/tmp/MyHelloTweak_CTOR_LOG.txt"

%ctor {
    // The constructor runs immediately when the dylib is loaded by dyld
    
    FILE *logFile = fopen(LOG_FILE_PATH, "a"); // Open file in append mode
    
    if (logFile) {
        time_t t = time(NULL);
        struct tm *tm = localtime(&t);
        // Use standard C time/date functions to avoid Objective-C frameworks
        fprintf(logFile, "Constructor executed at: %s", asctime(tm));
        fclose(logFile); // Close the file immediately
    }
}