#include<stdio.h>
#include<stdlib.h>
#include<sys/time.h>
#include<cuda.h>
#include<vector>
#include<math.h>
#include<cstring>
#include<utility>
#include<iostream> 
#include<algorithm>
using namespace std;

//structure for holding the file data(lines of string)
struct fileData{
    int *equal;
    char **lines;
};

void findingArgument(char *str, int len, bool argumentCapture[], bool err[])
{
	for(int i=1;i<len;i++){
		switch(str[i]){
			case 'c': argumentCapture[0] = true; break;
			case 'd': argumentCapture[1] = true; break;
			case 'D': argumentCapture[2] = true; break;
			case 'u': argumentCapture[3] = true; break;
			case 'i': argumentCapture[4] = true; break;
			default:  err[0] = true;
		}
		if(err[0]) return;
	}
}

void printVersion(){
	cout<<"Guniq (version: 1.0) is a GPU based implementation of uniq linux command utility."
               "\nWritten by Prasoon Mishra with love | 2021" <<endl;
}

void printHelping(){
    cout<<"Usage: ./Guniq [OPTION]... [INPUT [OUTPUT]]"
          "\nFilter adjacent matching lines from INPUT,"
          "\nwriting to OUTPUT (or standard output)."
          "\n"
          "\nWith no options, matching lines are merged to the first occurrence."
          "\n"
          "\nArguments::"
          "\n-c     prefix lines by the number of occurrences"
          "\n-d     only print duplicate lines, one for each group"
          "\n-D     print all duplicate lines"
          "\n-u     only print unique lines"
          "\n-i     ignore differences in case when comparing"
          "\n--version     output version information and exit"
          "\n--help     display this help and exit" 
          "\n\nNote: 'Guniq' does not detect repeated lines unless they are adjacent."<<endl;
}

__global__ void caseSensitiveKernel(int *GPUequal, char *GPUlines, int length, int count_lines){
    unsigned id = blockIdx.x*blockDim.x + threadIdx.x;
    if(id < count_lines-1){
        int fpos,spos,f;
        fpos = id*length;
        spos = (id+1)*length;
        f = 0;

        while(GPUlines[fpos] != '\n' && GPUlines[spos] != '\n'){
            if(GPUlines[fpos] != GPUlines[spos]){
                f = 1; break;
            }
            else{
                fpos++; spos++;
            } 
        }
        
        if(f != 1 && GPUlines[fpos] == GPUlines[spos]){
            GPUequal[id+1] = 1;
        }
    }
}

__global__ void caseInsensitiveKernel(int *GPUequal, char *GPUlines, int length, int count_lines){
    unsigned id = blockIdx.x*blockDim.x + threadIdx.x;
    if(id < count_lines-1){
        int fpos,spos,f;
        fpos = id*length;
        spos = (id+1)*length;
        f = 0;

        while( GPUlines[fpos] != '\n' && GPUlines[spos] != '\n' ){
            if( GPUlines[fpos] >= 'A' && GPUlines[fpos] <= 'Z' ){
                if(GPUlines[fpos] != GPUlines[spos] && GPUlines[fpos] +32 != GPUlines[spos]){
                    f = 1; break;
                }
                else{
                    fpos++; spos++;        
                }
            }
            else if( GPUlines[fpos] >= 'a' && GPUlines[fpos] <= 'z' ){
                if(GPUlines[fpos] != GPUlines[spos] && GPUlines[fpos] -32 != GPUlines[spos]){
                    f = 1; break;
                }
                else{
                    fpos++; spos++;        
                }
            }
            else if(GPUlines[fpos] != GPUlines[spos]){
                f = 1; break;
            }
            else{
                fpos++; spos++;
            } 
        }//end of while
        
        if(f != 1 && GPUlines[fpos] == GPUlines[spos]){
            GPUequal[id+1] = 1;
        }
    }
}

void printError(int i){
        switch(i){
        case 0: cout<<"Error: Synatax not followed properly.\n i.e No arguments should be after file names."<<endl; break;
        case 1: cout<<"Error: Synatax not followed properly.\n i.e Not more than two file names(input & output) should be passed."<<endl; break;
        case 2: cout<<"Error: Synatax not followed properly.\n i.e Unknown arguments passed."<<endl; break;
        default: cout<<"Error: Synatax not followed properly. Use ./Guniq --help for further help."<<endl;; break;
    }
}

int main(int argc, char **argv){

	//error variable
	bool err[1];
	err[0] = false;

	//array for knowing which argument was used
	//argumentCapture capture info about ['c','d','D','u','i'] arguments by putting true/false at respective positions
	bool argumentCapture[5];
	for(int i=0; i<5; i++)
		argumentCapture[i] = false;

	//finding options used in this command
	bool temp = false;
	int fileNameIndex1 = -1, fileNameIndex2 = -1; 
	for(int i=1; i<argc; i++){

		if(strcmp(argv[i], "--version") == 0){
			printVersion();
			exit(0);
		}
		if(strcmp(argv[i], "--help") == 0){
			printHelping();
			exit(0);
		}

		if(strncmp(argv[i],"-", 1) == 0 && temp){
			printError(0);
			exit(0);
		}
		else if(strncmp(argv[i],"-", 1) == 0){
			int len = strlen(argv[i]);
			findingArgument(argv[i], len, argumentCapture, err);
		}
		else
		{
			temp = true;
			if(fileNameIndex1 == -1) fileNameIndex1 = i;
			else if(fileNameIndex2 == -1) fileNameIndex2 = i;
			else{
                printError(1);
				exit(0);
			}
		}

		if(err[0]){
			printError(2);
			exit(0);
		}
	}//end of for

	//Checking of above code
	// printf("c:%s\n", argumentCapture[0] ? "true" : "false");
	// printf("d:%s\n", argumentCapture[1] ? "true" : "false");
	// printf("D:%s\n", argumentCapture[2] ? "true" : "false");
	// printf("u:%s\n", argumentCapture[3] ? "true" : "false");
	// printf("i:%s\n", argumentCapture[4] ? "true" : "false");

	if(argumentCapture[0] && argumentCapture[2]){
		printf("Guniq: printing all duplicated lines and repeat counts is meaningless. Try './Guniq --help' for more information.\n");
		exit(0);
	}

	if(argumentCapture[1] && argumentCapture[3]){
		printf("Guniq: printing only duplicated lines only and printing only unique lines only is meaningless. Try './Guniq --help' for more information.\n");
		exit(0);
	}

	if(argumentCapture[1] && argumentCapture[2]){
		printf("Guniq: printing all duplicated lines and printing only one duplicate lines for each group is counter arguments. Hence meaningless. Try './Guniq --help' for more information.\n");
		exit(0);
	}

	if(argumentCapture[2] && argumentCapture[3]){
		printf("Guniq: printing only duplicated lines only and printing only unique lines only is meaningless. Try './Guniq --help' for more information.\n");
		exit(0);
	}

	if(fileNameIndex1 == -1 && fileNameIndex2 == -1){
		printf("Error: No file was passed as argument. Pls try again!\n");
		exit(0);
	}

	//Computing the uniq for arguments which do not have "i"
	if(!argumentCapture[4]){
		char *inputfilename = argv[fileNameIndex1];
        FILE *fileptr;
        fileptr = fopen(inputfilename , "r");

        if (fileptr == NULL){
            printf( "Error: Input file failed to open." );
            return 0;
        }

        // printf("%s\n",inputfilename);

        int count_lines = 0;
        int max_len = 0, max = 0;
        char chr;
        chr = getc(fileptr);
        while (chr != EOF)
        {
            //Count whenever new line is encountered
            if (chr == '\n'){
                //Calculating the total lines in string and also the max length of the string
                count_lines = count_lines + 1;
                if(max_len < max) max_len = max;
                max = 0;
            }
            else max++;

            //take next character from file.
            chr = getc(fileptr);
        }
        rewind(fileptr); 

        //variable declaration
        fileData data;
        int *GPUequal;
        char *GPUlines;
        char *datalines;

        //memory allocation
        data.equal = (int*) calloc(count_lines,sizeof(int));
        data.lines = (char **) malloc(count_lines * sizeof(char *));  
        for(int i=0; i<count_lines; i++){
            data.lines[i] = (char *) malloc((max_len+2) * sizeof(char));
        }
        datalines = (char *)malloc(count_lines * (max_len+2) * sizeof(char));
        cudaMalloc(&GPUequal, count_lines * sizeof(int));
        cudaMalloc(&GPUlines, count_lines * (max_len+2) * sizeof(char));      

        // printf("count_lines=%d, max_len=%d\n", count_lines, max_len);

        // char tempLine[max_len+1];
        int i=0;
        //copying the data
        char * line = NULL;
    	size_t len = 0;
    	ssize_t read;

    	while ((read = getline(&line, &len, fileptr)) != -1) {
    		strcpy(data.lines[i],line);
    		i++;
    	}
    	i=0; 

        fclose(fileptr);

        //Copying 2d array to 1d array in CPU
        int k = 0, j = 0;
        for( i=0 ; i<count_lines; i++ ){
            k = i*(max_len+2);
            while(data.lines[i][j] != '\n'){
                datalines[k] = data.lines[i][j];
                //cout<<datalines[k];
                k++;
                j++;
            }
            j = 0;
            datalines[k] = '\n';
            //cout<<datalines[k];
        }

        //For timing the cuda kernel, serial logic and print/file printing
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);
        float milliseconds = 0;
        cudaEventRecord(start,0);


        //Initialization in GPU
        cudaMemcpy(GPUequal, data.equal, count_lines * sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(GPUlines, datalines, count_lines*(max_len+2)*sizeof(char), cudaMemcpyHostToDevice);

        // for(i=0; i<count_lines; i++){
        // 	printf("%s",data.lines[i]);
        // }

        // processing of uniq main thing in GPU
        int StringLength = max_len+2;
        int NUM_THREADS = 1024;
        int NUM_BLOCKS = (ceil)((double)count_lines/NUM_THREADS);

        caseSensitiveKernel<<<NUM_BLOCKS, NUM_THREADS>>>(GPUequal, GPUlines, StringLength, count_lines);
        
        //copying back from GPU to CPU
        cudaMemcpy(data.equal, GPUequal, count_lines * sizeof(int), cudaMemcpyDeviceToHost);

        //Serial code        
        // for(i=0; i<count_lines-1; i++){
        //     if(strcmp( data.lines[i], data.lines[i+1]) == 0) data.equal[i+1] = 1;
        // }

        int backCounter = 0;
        for(i=count_lines-1; i>=0; i--){
            if(data.equal[i] == 1){
                data.equal[i] = -1;
                backCounter++;
            }
            else{
                data.equal[i] = backCounter;
                backCounter = 0;
            }
        }
        //serial code ends

        //printing
        if(argumentCapture[0]){
        	if(argumentCapture[1]){
	        	if(fileNameIndex2 != -1){
		            char *outputfilename = argv[fileNameIndex2];
		            fileptr = fopen(outputfilename , "w");
		            
		            if (fileptr == NULL){
		                printf( "Output file failed to open." );
		                exit(0);
	                }

	                for(i=0; i<count_lines; i++){
	                    if(data.equal[i] > 0){
	                        fprintf(fileptr, "%7d %s",data.equal[i]+1,data.lines[i]);
	                    }
	                }
	                fclose(fileptr);
        		}
        		else{
                	for(i=0; i<count_lines; i++){
                    	// printf("%d %s",data.equal[i], data.lines[i]);
                    	if(data.equal[i] > 0){
                        	printf("%7d %s",data.equal[i]+1, data.lines[i]);
                    	}
                	}     			  
        		}
        	}
        	else if(argumentCapture[3]){
	        	if(fileNameIndex2 != -1){
		            char *outputfilename = argv[fileNameIndex2];
		            fileptr = fopen(outputfilename , "w");
		            
		            if (fileptr == NULL){
		                printf( "Output file failed to open." );
		                exit(0);
	                }

	                for(i=0; i<count_lines; i++){
	                    if(data.equal[i] == 0){
	                        fprintf(fileptr, "%7d %s",data.equal[i]+1,data.lines[i]);
	                    }
	                }
	                fclose(fileptr);
        		}
        		else{
                	for(i=0; i<count_lines; i++){
                    	// printf("%d %s",data.equal[i], data.lines[i]);
                    	if(data.equal[i] == 0){
                        	printf("%7d %s",data.equal[i]+1, data.lines[i]);
                    	}
                	}       			  
        		}        		
        	}
        	else{
	        	if(fileNameIndex2 != -1){
		            char *outputfilename = argv[fileNameIndex2];
		            fileptr = fopen(outputfilename , "w");
		            
		            if (fileptr == NULL){
		                printf( "Output file failed to open." );
		                exit(0);
	                }

	                for(i=0; i<count_lines; i++){
	                    if(data.equal[i] >= 0){
	                        fprintf(fileptr, "%7d %s",data.equal[i]+1,data.lines[i]);
	                    }
	                }
	                fclose(fileptr);
        		}
        		else{
                	for(i=0; i<count_lines; i++){
                    	// printf("%d %s",data.equal[i], data.lines[i]);
                    	if(data.equal[i] >= 0){
                        	printf("%7d %s",data.equal[i]+1, data.lines[i]);
                    	}
                	}        			  
        		} 
        	}
        }
        else if(argumentCapture[1]){
        	if(fileNameIndex2 != -1){
	            char *outputfilename = argv[fileNameIndex2];
	            fileptr = fopen(outputfilename , "w");
	            
	            if (fileptr == NULL){
	                printf( "Output file failed to open." );
	                exit(0);
                }

                for(i=0; i<count_lines; i++){
                    if(data.equal[i] > 0){
                        fprintf(fileptr, "%s",data.lines[i]);
                    }
                }
                fclose(fileptr);
    		}
    		else{
            	for(i=0; i<count_lines; i++){
                	// printf("%d %s",data.equal[i], data.lines[i]);
                	if(data.equal[i] > 0){
                    	printf("%s",data.lines[i]);
                	}
            	}      			  
    		} 
        }
        else if(argumentCapture[2]){
	        	if(fileNameIndex2 != -1){
		            char *outputfilename = argv[fileNameIndex2];
		            fileptr = fopen(outputfilename , "w");
		            
		            if (fileptr == NULL){
		                printf( "Output file failed to open." );
		                exit(0);
	                }

	                for(i=0; i<count_lines; i++){
	                    if(data.equal[i] != 0){
	                        fprintf(fileptr, "%s",data.lines[i]);
	                    }
	                }
	                fclose(fileptr);
        		}
        		else{
                	for(i=0; i<count_lines; i++){
                    	// printf("%d %s",data.equal[i], data.lines[i]);
                    	if(data.equal[i] != 0){
                        	printf("%s",data.lines[i]);
                    	}
                	}      			  
        		} 
        }        	
        else if(argumentCapture[3]){
        	if(fileNameIndex2 != -1){
	            char *outputfilename = argv[fileNameIndex2];
	            fileptr = fopen(outputfilename , "w");
	            
	            if (fileptr == NULL){
	                printf( "Output file failed to open." );
	                exit(0);
                }

                for(i=0; i<count_lines; i++){
                    if(data.equal[i] == 0){
                        fprintf(fileptr, "%s",data.lines[i]);
                    }
                }
                fclose(fileptr);
    		}
    		else{
            	for(i=0; i<count_lines; i++){
                	// printf("%d %s",data.equal[i], data.lines[i]);
                	if(data.equal[i] == 0){
                    	printf("%s",data.lines[i]);
                	}
            	}        			  
    		} 
        }
        else{
        	if(fileNameIndex2 != -1){
	            char *outputfilename = argv[fileNameIndex2];
	            fileptr = fopen(outputfilename , "w");
	            
	            if (fileptr == NULL){
	                printf( "Output file failed to open." );
	                exit(0);
                }

                for(i=0; i<count_lines; i++){
                    if(data.equal[i] >= 0){
                        fprintf(fileptr, "%s",data.lines[i]);
                    }
                }
                fclose(fileptr);
    		}
    		else{
            	for(i=0; i<count_lines; i++){
                	// printf("%d %s",data.equal[i], data.lines[i]);
                	if(data.equal[i] >= 0){
                    	printf("%s",data.lines[i]);
                	}
            	}      			  
    		}         	
        }

        cudaEventRecord(stop,0);
        cudaEventSynchronize(stop);
        cudaEventElapsedTime(&milliseconds, start, stop);
        printf("Time taken by function to execute is: %.6f ms\n", milliseconds);


        //deleting memory allocated
        for(i = 0; i<count_lines; i++){
            delete(data.lines[i]);
        }
        delete(data.equal);
	}
	else{
        char *inputfilename = argv[fileNameIndex1];
        FILE *fileptr;
        fileptr = fopen(inputfilename , "r");

        if (fileptr == NULL){
            printf( "Error: Input file failed to open." );
            return 0;
        }

        // printf("%s\n",inputfilename);

        int count_lines = 0;
        int max_len = 0, max = 0;
        char chr;
        chr = getc(fileptr);
        while (chr != EOF)
        {
            //Count whenever new line is encountered
            if (chr == '\n'){
                //Calculating the total lines in string and also the max length of the string
                count_lines = count_lines + 1;
                if(max_len < max) max_len = max;
                max = 0;
            }
            else max++;

            //take next character from file.
            chr = getc(fileptr);
        }
        rewind(fileptr); 

        //variable declaration
        fileData data;
        int *GPUequal;
        char *GPUlines;
        char *datalines;

        //memory allocation
        data.equal = (int*) calloc(count_lines,sizeof(int));
        data.lines = (char **) malloc(count_lines * sizeof(char *));  
        for(int i=0; i<count_lines; i++){
            data.lines[i] = (char *) malloc((max_len+2) * sizeof(char));
        }
        datalines = (char *)malloc(count_lines * (max_len+2) * sizeof(char));
        cudaMalloc(&GPUequal, count_lines * sizeof(int));
        cudaMalloc(&GPUlines, count_lines * (max_len+2) * sizeof(char));      

        // printf("count_lines=%d, max_len=%d\n", count_lines, max_len);

        // char tempLine[max_len+1];
        int i=0;
        //copying the data
        char * line = NULL;
        size_t len = 0;
        ssize_t read;

        while ((read = getline(&line, &len, fileptr)) != -1) {
            strcpy(data.lines[i],line);
            i++;
        }
        i=0; 

        fclose(fileptr);

        //Copying 2d array to 1d array in CPU
        int k = 0, j = 0;
        for( i=0 ; i<count_lines; i++ ){
            k = i*(max_len+2);
            while(data.lines[i][j] != '\n'){
                datalines[k] = data.lines[i][j];
                //cout<<datalines[k];
                k++;
                j++;
            }
            j = 0;
            datalines[k] = '\n';
            //cout<<datalines[k];
        }

        //For timing the cuda kernel, serial logic and print/file printing
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);
        float milliseconds = 0;
        cudaEventRecord(start,0);


        //Initialization in GPU
        cudaMemcpy(GPUequal, data.equal, count_lines * sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(GPUlines, datalines, count_lines*(max_len+2)*sizeof(char), cudaMemcpyHostToDevice);

        // for(i=0; i<count_lines; i++){
        //  printf("%s",data.lines[i]);
        // }

        // processing of uniq main thing in GPU
        int StringLength = max_len+2;
        int NUM_THREADS = 1024;
        int NUM_BLOCKS = (ceil)((double)count_lines/NUM_THREADS);

        caseInsensitiveKernel<<<NUM_BLOCKS, NUM_THREADS>>>(GPUequal, GPUlines, StringLength, count_lines);
        
        //copying back from GPU to CPU
        cudaMemcpy(data.equal, GPUequal, count_lines * sizeof(int), cudaMemcpyDeviceToHost);

        //Serial code        
        // for(i=0; i<count_lines-1; i++){
        //     if(strcmp( data.lines[i], data.lines[i+1]) == 0) data.equal[i+1] = 1;
        // }

        int backCounter = 0;
        for(i=count_lines-1; i>=0; i--){
            if(data.equal[i] == 1){
                data.equal[i] = -1;
                backCounter++;
            }
            else{
                data.equal[i] = backCounter;
                backCounter = 0;
            }
        }
        //serial code ends

        //printing
        if(argumentCapture[0]){
            if(argumentCapture[1]){
                if(fileNameIndex2 != -1){
                    char *outputfilename = argv[fileNameIndex2];
                    fileptr = fopen(outputfilename , "w");
                    
                    if (fileptr == NULL){
                        printf( "Output file failed to open." );
                        exit(0);
                    }

                    for(i=0; i<count_lines; i++){
                        if(data.equal[i] > 0){
                            fprintf(fileptr, "%7d %s",data.equal[i]+1,data.lines[i]);
                        }
                    }
                    fclose(fileptr);
                }
                else{
                    for(i=0; i<count_lines; i++){
                        // printf("%d %s",data.equal[i], data.lines[i]);
                        if(data.equal[i] > 0){
                            printf("%7d %s",data.equal[i]+1, data.lines[i]);
                        }
                    }                 
                }
            }
            else if(argumentCapture[3]){
                if(fileNameIndex2 != -1){
                    char *outputfilename = argv[fileNameIndex2];
                    fileptr = fopen(outputfilename , "w");
                    
                    if (fileptr == NULL){
                        printf( "Output file failed to open." );
                        exit(0);
                    }

                    for(i=0; i<count_lines; i++){
                        if(data.equal[i] == 0){
                            fprintf(fileptr, "%7d %s",data.equal[i]+1,data.lines[i]);
                        }
                    }
                    fclose(fileptr);
                }
                else{
                    for(i=0; i<count_lines; i++){
                        // printf("%d %s",data.equal[i], data.lines[i]);
                        if(data.equal[i] == 0){
                            printf("%7d %s",data.equal[i]+1, data.lines[i]);
                        }
                    }                     
                }               
            }
            else{
                if(fileNameIndex2 != -1){
                    char *outputfilename = argv[fileNameIndex2];
                    fileptr = fopen(outputfilename , "w");
                    
                    if (fileptr == NULL){
                        printf( "Output file failed to open." );
                        exit(0);
                    }

                    for(i=0; i<count_lines; i++){
                        if(data.equal[i] >= 0){
                            fprintf(fileptr, "%7d %s",data.equal[i]+1,data.lines[i]);
                        }
                    }
                    fclose(fileptr);
                }
                else{
                    for(i=0; i<count_lines; i++){
                        // printf("%d %s",data.equal[i], data.lines[i]);
                        if(data.equal[i] >= 0){
                            printf("%7d %s",data.equal[i]+1, data.lines[i]);
                        }
                    }                     
                } 
            }
        }
        else if(argumentCapture[1]){
            if(fileNameIndex2 != -1){
                char *outputfilename = argv[fileNameIndex2];
                fileptr = fopen(outputfilename , "w");
                
                if (fileptr == NULL){
                    printf( "Output file failed to open." );
                    exit(0);
                }

                for(i=0; i<count_lines; i++){
                    if(data.equal[i] > 0){
                        fprintf(fileptr, "%s",data.lines[i]);
                    }
                }
                fclose(fileptr);
            }
            else{
                for(i=0; i<count_lines; i++){
                    // printf("%d %s",data.equal[i], data.lines[i]);
                    if(data.equal[i] > 0){
                        printf("%s",data.lines[i]);
                    }
                }                 
            } 
        }
        else if(argumentCapture[2]){
                if(fileNameIndex2 != -1){
                    char *outputfilename = argv[fileNameIndex2];
                    fileptr = fopen(outputfilename , "w");
                    
                    if (fileptr == NULL){
                        printf( "Output file failed to open." );
                        exit(0);
                    }

                    for(i=0; i<count_lines; i++){
                        if(data.equal[i] != 0){
                            fprintf(fileptr, "%s",data.lines[i]);
                        }
                    }
                    fclose(fileptr);
                }
                else{
                    for(i=0; i<count_lines; i++){
                        // printf("%d %s",data.equal[i], data.lines[i]);
                        if(data.equal[i] != 0){
                            printf("%s",data.lines[i]);
                        }
                    }                 
                } 
        }           
        else if(argumentCapture[3]){
            if(fileNameIndex2 != -1){
                char *outputfilename = argv[fileNameIndex2];
                fileptr = fopen(outputfilename , "w");
                
                if (fileptr == NULL){
                    printf( "Output file failed to open." );
                    exit(0);
                }

                for(i=0; i<count_lines; i++){
                    if(data.equal[i] == 0){
                        fprintf(fileptr, "%s",data.lines[i]);
                    }
                }
                fclose(fileptr);
            }
            else{
                for(i=0; i<count_lines; i++){
                    // printf("%d %s",data.equal[i], data.lines[i]);
                    if(data.equal[i] == 0){
                        printf("%s",data.lines[i]);
                    }
                }                     
            } 
        }
        else{
            if(fileNameIndex2 != -1){
                char *outputfilename = argv[fileNameIndex2];
                fileptr = fopen(outputfilename , "w");
                
                if (fileptr == NULL){
                    printf( "Output file failed to open." );
                    exit(0);
                }

                for(i=0; i<count_lines; i++){
                    if(data.equal[i] >= 0){
                        fprintf(fileptr, "%s",data.lines[i]);
                    }
                }
                fclose(fileptr);
            }
            else{
                for(i=0; i<count_lines; i++){
                    // printf("%d %s",data.equal[i], data.lines[i]);
                    if(data.equal[i] >= 0){
                        printf("%s",data.lines[i]);
                    }
                }                 
            }           
        }

        cudaEventRecord(stop,0);
        cudaEventSynchronize(stop);
        cudaEventElapsedTime(&milliseconds, start, stop);
        printf("Time taken by function to execute is: %.6f ms\n", milliseconds);


        //deleting memory allocated
        for(i = 0; i<count_lines; i++){
            delete(data.lines[i]);
        }
        delete(data.equal);
	}
}

