u_seq_sep <-c(251.452, 615.097) # Uncached sequential code separate
c_seq_tog <-c(34.695, 73.120) # Cached sequential code together 

u_par_sep <-c(430.112, 529.942) # Uncached parallel code separate
c_par_tog <-c(36.276, 75.029) # Cached parallel code together
u_c_tog <-c(143.213, 529.942) # Uncached and Cached total together 

function_names <- c("Single Precision", "Double Precision")

# Uncached Sequential code histogram
barplot(u_seq_sep, 
     main="Uncached Sequential code ", 
     xlab="Functions Run", ylab="Time Taken in milliseconds",
     names.arg = function_names)
# Cached Sequential code histogram Together
barplot(c_seq_tog, 
     main="Cached Sequential code together",
     xlab="Functions Run", ylab="Time Taken in milliseconds",
     names.arg = function_names)
# Uncached Parrallel code histogram
barplot(u_par_sep, 
     main="Uncached Parrallel code",
     xlab="Functions Run", ylab="Time Taken in milliseconds",
     names.arg = function_names)
# Cached Parrallel code histogram together
barplot(c_par_tog, 
     main="Cached Parrallel code together",
     xlab="Functions Run", ylab="Time Taken in milliseconds",
     names.arg = function_names)
# Unached Cached code together
barplot(u_c_tog,
     main="Unached and Cached total code together",
     xlab="Functions Run", ylab="Time Taken in milliseconds",
     names.arg = function_names)
