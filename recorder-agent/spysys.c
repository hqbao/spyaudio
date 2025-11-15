#include <stdio.h>
#include <time.h>
#include <unistd.h>

/**
 * @brief Prints the current timestamp.
 * * This program is designed to be executed by launchd periodically, 
 * printing its output to the log file specified in the plist.
 * It is not an infinite loop.
 */
int main(void) {
    // Get the current time
    time_t timer;
    char buffer[26];
    struct tm* tm_info;

    while (1) {
        time(&timer);
        tm_info = localtime(&timer);

        // Format the time string (e.g., 2024-01-01 12:30:00)
        strftime(buffer, 26, "%Y-%m-%d %H:%M:%S", tm_info);

        // Print only the time (this will go to StandardOutPath in the plist)
        printf("Daemon1 ran at: %s\n", buffer);

        // Ensures the output buffer is flushed immediately.
        fflush(stdout);

        sleep(1);
    }

    return 0;
}