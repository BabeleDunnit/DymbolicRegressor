
import std.stdio;
import std.math;
import std.moduleinit;
import std.random;
import std.string;
import std.cstream;
import std.gc;
import std.cpuid;
import std.date;
import std.conv;
import std.file;
import std.stream;


import regressiondata;
import operators;
import individual;
import generation;
import population;
import rangedetector;


version = oldTournament;
version = diversity;

bool continueEvolution = true;

char[] programName = "Dymbolic Regressor 0.3 by Babele Dunnit";

char[] dataFolderName()
{

    d_time time = getUTCtime;

    d_time t;
    char sign;
    int hr;
    int mn;
    int len;
    d_time offset;
    d_time dst;

    // Years are supposed to be -285616 .. 285616, or 7 digits
    // "Tue Apr 02 02:04:57 GMT-0800 1996"
    char[] buffer = new char[29 + 7 + 1];

    if (time == d_time_nan)
	return "Invalid Date";

    dst = DaylightSavingTA(time);
    offset = LocalTZA + dst;
    t = time + offset;
    sign = '+';
    if (offset < 0)
    {	sign = '-';
//	offset = -offset;
	offset = -(LocalTZA + dst);
    }

    mn = cast(int)(offset / msPerMinute);
    hr = mn / 60;
    mn %= 60;

    //printf("hr = %d, offset = %g, LocalTZA = %g, dst = %g, + = %g\n", hr, offset, LocalTZA, dst, LocalTZA + dst);

/*
    len = sprintf(buffer.ptr, "%d  %d %d %02d:%02d:%02d",
	cast(long)YearFromTime(t),
	MonthFromTime(t),
	DateFromTime(t),
	HourFromTime(t), MinFromTime(t), SecFromTime(t));
	*/


    len = sprintf(buffer.ptr, "%d.%02d.%02d-%02d.%02d.%02d",
	YearFromTime(t),
	MonthFromTime(t)+1,
	DateFromTime(t),
	HourFromTime(t), MinFromTime(t), SecFromTime(t));

    // Ensure no buggy buffer overflows
    //printf("len = %d, buffer.length = %d\n", len, buffer.length);
    assert(len < buffer.length);

    return buffer[0 .. len];
}


int main(char[][] args)
{

    writefln();
    writefln(programName);

    uint nParallelThreads = threadsPerCPU * coresPerCPU;

    int minGrowDepth = 2;
    int maxGrowDepth = 7;
    int minGrowNodes = 3;
    int maxGrowNodes = 15;

    RegressionData problemRD = new RegressionData;
    char[] problemDataFilename = "problem.dat";

    RegressionData testRD = new RegressionData;
    char[] testDataFilename = "test.dat";

    // parse options
    foreach(i, o; args)
    {

        switch(o)
        {

        case "-h":
        case "-?":
        case "-help":
            writefln("\n%s", programName);
            writefln("-t N : run with N parallel evaluation threads (default: %d)", nParallelThreads);
            writefln("-n N : run with N maximum nodes (i.e, formula length; default: %d)", maxGrowNodes);
            writefln("-r : reset serialized state (move everything in a subdirectory and restart)");
            writefln("-fp <filename>: use <filename> as regression dataset (default: %s)", problemDataFilename);
            writefln("-ft <filename>: use <filename> as testing dataset (default: %s)", testDataFilename);
            writefln("-autotest: generate 'autotest.dat' regression dataset and use it");
            return 0;
            break;

        case "-fp":
            problemDataFilename = args[i+1];
            writefln("Found Command Line Option: -fp : use <%s> as regression dataset", problemDataFilename );
            break;

        case "-ft":
            testDataFilename = args[i+1];
            writefln("Found Command Line Option: -ft : use <%s> as testing dataset", testDataFilename );
            break;

        case "-autotest":
            problemRD.generateTestFile("autotest.dat");
            problemDataFilename = "autotest.dat";
            testRD = null;
            break;


        case "-t":
            {
            int reqParallelThreads = toInt(args[i+1]);
            writefln("Found Command Line Option: -t : request for %d parallel evaluation threads", reqParallelThreads );
            if( reqParallelThreads < nParallelThreads )
                nParallelThreads = reqParallelThreads;
            }
            break;

        case "-n":
            maxGrowNodes = toInt(args[i+1]);
            writefln("Found Command Line Option: -n : request for %d nodes", maxGrowNodes);
            break;

        case "-r":
            {
            writefln("Found Command Line Option: -r : reset serialized state");
            char[] targetFolder = dataFolderName;
            mkdir(targetFolder);
            std.file.rename("generations.txt", targetFolder ~ "/generations.txt");
            std.file.rename("population.dat", targetFolder ~ "/population.dat");
            std.file.copy("problem.dat", targetFolder ~ "/problem.dat");
            writefln("Files moved into folder <%s>", targetFolder);
            return 0;
            }
            break;

        default:
            break;

        }

    }


    bool found = problemRD.readData(problemDataFilename);
    if(!found)
    {
        writefln("Regression dataset not found: <%s> - cannot proceed", problemDataFilename);
        return 1;
    }


    found = testRD.readData(testDataFilename);
    if(!found)
    {
        writefln("Test dataset not found: <%s> - classification testing functions disabled", testDataFilename);
        testRD = null;
    }
    else
    {
        if(testRD.dimensions != problemRD.dimensions)
        {
            writefln("Test and regression datasets must have same dimensions - cannot proceed");
            return 1;
        }
    }


    int nIndividuals = 50000;

    // il torneo consiste nel prendere (minimo) N individui a caso e vedere quale ha la fitness piu' alta...
    int tournamentSize = 10;

    // vincitori di torneo: questo e' il numero di vincitori (in percentuale) rispetto alla popolazione globale.
    // ad esempio, 0.2 significa che da una popolazione di 30.000 individui viene generata una popolazione
    // di 6000 vincitori di torneo. Su questa vengono poi fatti i crossbreed; questi NON finiscono direttamente nella prossima generazione,
    // a parte il primo che e' il MIGLIORE in assoluto..
    real tournamentWinnersPercent = 0.5;

    // le seguenti sono le percentuali di quello che si trova nella nuova popolazione; ovviamente la somma deve fare 1.0

    // mutazioni del best della popolazione precedente. NB: qui dentro ci sbattiamo anche qualche caso particolare, ovvero il
    // best del giro precendente copiato pari pari, la sua semplificazione etc.
    real mutationsPercent = 0.01;

    // crossbreed generati dai vincitori di torneo
    real winnersCrossbreedsPercent = 0.49;

    // nuovi individui generati a caso
    real newIndividualsPercent = 0.5;


    int nTournamentWinners = cast(int) (nIndividuals * tournamentWinnersPercent + 0.5);

    int nMutations = cast(int) (nIndividuals * mutationsPercent + 0.5);
    int nWinnersCrossbreeds = cast(int) (nIndividuals * winnersCrossbreedsPercent + 0.5);
    int nNewIndividuals = cast(int) (nIndividuals * newIndividualsPercent + 0.5);

    assert(nMutations + nWinnersCrossbreeds + nNewIndividuals == nIndividuals);
    assert(mutationsPercent + winnersCrossbreedsPercent + newIndividualsPercent == 1.0);

    int maxGenerations = 99999;

    real growTerminationProbability = 0.2;



// snippet per filtrare il file in due
version(filtrozzo)
{

        Stream infile = new BufferedFile("problem.dat");
        Stream outfile1 = new BufferedFile("solo035.dat", FileMode.Out);
        Stream outfile2 = new BufferedFile("misto.dat", FileMode.Out);

        foreach(ulong lineNum, char[] line; infile)
        {
//            writefln("line %d: %s",lineNum,line);
            char[][] values = std.string.split(line);
            int dims = values.length;
            real f = toReal(values[dims-1]);

            if( 0.3 <= f && f <= 0.4)
                outfile1.writeLine(line);
            else
                outfile2.writeLine(line);
        }

        infile.close();
        outfile1.close();
        outfile2.close();
        assert(0);
}



version(splittaloInDue)
{
        RegressionData rd = new RegressionData;
        bool found = rd.readData("problem.dat");

        if(!found)
        {
            rd.generateTestFile("generated_problem.dat");
            found = rd.readData("generated_problem.dat");
            assert(found);
        }


    //    rd.more(15);
        rd.shuffleLines;
    //    writefln();
    //    rd.more(15);
    //
    //    assert(0);


    //    rd.more(15);
    int oriLen = rd.length;
        headRd = rd.split(cast(int) (rd.length * 0.8));
        tailRd = rd;
        rd = null;
    //    writefln();
    //    rd.more(15);
    //    writefln();
    //    head.more(15);

        assert(headRd.length + tailRd.length == oriLen);
}

    OperatorsFactory of1 = new OperatorsFactory(problemRD.dimensions);
    of1.addOperator("Add");
    of1.addOperator("Sub");
    of1.addOperator("Mult");
    //of1.addOperator("Div");
    // of1.addOperator("Pow");
    //of1.addOperator("Sin");
    //of1.addOperator("Cos");
    //of1.addOperator("Exp");
    //of1.addOperator("Log");
    //of1.addOperator("Abs");

    void printHeader(FILE* f)
    {

        fwritefln(f, programName);
        fwritefln(f, "Run Date/Time: %s", std.date.toString(getUTCtime()));
        fwritefln(f, "Population Size: %d", nIndividuals);
        fwritefln(f, "Tournament Fights: %d", tournamentSize);
        fwritefln(f, "Tournament Winners: %d", nTournamentWinners);
        fwritefln(f, "Min-Max Grow Depth: %d - %d", minGrowDepth, maxGrowDepth);
        fwritefln(f, "Min-Max Grow Nodes: %d - %d", minGrowNodes, maxGrowNodes);
        fwritefln(f, "Grow Termination Probability: %.2f", growTerminationProbability);
        fwritefln(f, "New Population Percents: Mutations %.2f, Crossbreeds %.2f, New Individuals %.2f",
            mutationsPercent, winnersCrossbreedsPercent, newIndividualsPercent);
        fwritefln(f, "Operators Used: %s", of1.operatorsToUse);
        fwritefln(f, "Lines to Regress: %d", problemRD.length);
        fwritefln(f, "Problem DataSet: <%s>, %d lines, Dimension: %d, Ranges:", problemDataFilename, problemRD.length, problemRD.dimensions);
        for(int i = 0; i < problemRD.dimensions; i++)
            fwritefln(f, "X%d : %s", i, problemRD.rangeDetectors[i]);
        fwritefln(f, "F : %s", problemRD.rangeDetectors[problemRD.dimensions]);

        if(testRD)
        {
            fwritefln(f, "Test DataSet: <%s>, %d Lines, Dimension: %d, Ranges:", testDataFilename, testRD.length, testRD.dimensions);
            for(int i = 0; i <testRD.dimensions; i++)
                fwritefln(f, "X%d : %s", i, testRD.rangeDetectors[i]);
            fwritefln(f, "F : %s", testRD.rangeDetectors[testRD.dimensions]);
        }

        fflush(f);
    }


    printHeader(stdout);

    writefln("threads x CPU: %d", threadsPerCPU);
    writefln("cores x CPU: %d", coresPerCPU);
    writefln("hyperthreading: %d", hyperThreading);

    writefln("running with %d parallel eval threads", nParallelThreads);

/*
    Individual testInd = new Individual;
    testInd.grow(of1, 3, 5, 10, 0.0);
    testInd.eval(rd);
    writefln(testInd);

    Individual simply = testInd.simplify();
    writefln(simply);

    writefln(testInd.classinfo.name);

    Operator n = new Constant;
    writefln(n.classinfo.name);

    assert(0);


    testInd.save("individuo.dat");

    Individual testInd2 = new Individual;
    testInd2.load("individuo.dat");

    writefln("%s\n\n%s", testInd, testInd2);

    Population testPop = new Population;
    testPop ~= testInd;

    testPop.save("popolazione.dat");

    Population testPop2 = new Population;
    testPop2.load("popolazione.dat");
*/

/*


    Individual father = new Individual;
    Individual mother = new Individual;
    Individual figlio;

    for(int uu = 0; uu < 1000000; uu++)
    {
    father.grow(of1, minGrowDepth, maxGrowDepth, maxGrowNodes, 0.5);
    //writefln(father);

    mother.grow(of1, minGrowDepth, maxGrowDepth, maxGrowNodes, 0.5);
    //writefln(mother);

    crossover(father, mother, figlio, minGrowNodes, maxGrowNodes);
    //writefln(figlio);
    }



        for(int uu = 0; uu < 1000000; uu++)
        {
            Individual son;

            int randomWinner1 = rand() % zippoPop.individuals.length;
            int randomWinner2 = rand() % zippoPop.individuals.length;

            try
            {
            crossover(tournamentWinnersPop.individuals[randomWinner1], tournamentWinnersPop.individuals[randomWinner2], son, minGrowNodes, maxGrowNodes);
            }
            catch(Exception e)
            {
                writefln(e.msg);
                writefln("si e' incartato su questi, indici %d %d:", randomWinner1, randomWinner2);
                writefln(tournamentWinnersPop.individuals[randomWinner1]);
                writefln(tournamentWinnersPop.individuals[randomWinner2]);

            }

            winnersCrossbreedsPop.individuals[nic] = son;

            if(nic % (nWinnersCrossbreeds / 10) == 0)
            {
                writef("..%d%%..", nic * 100 / nWinnersCrossbreeds);
                dout.flush();
            }

        }




assert(0);

*/

    // RangeDetector!(real) r = new RangeDetector!(real);

    Population initPop = new Population(nIndividuals);

/*
    Population testPop1 = new Population(20000);
    Population testPop2 = new Population(20000);

    Individual[] indi;
    indi.length = 40000;

    for(int uu = 0; uu < 100; uu++)
    {
        testPop1.grow(of1, minGrowDepth, maxGrowDepth, maxGrowNodes, growTerminationProbability);
        testPop2.grow(of1, minGrowDepth, maxGrowDepth, maxGrowNodes, growTerminationProbability);
        auto tmp =  testPop1.individuals ~ testPop2.individuals;
        initPop.individuals = tmp;

        //indi = testPop1.individuals ~ testPop2.individuals;
        //indi[0..20000] = testPop1.individuals;
        //indi[20000..40000] = testPop2.individuals;

        // assert(initPop.individuals.length == nIndividuals);

        //fullCollect();
    }

    assert(0);
*/

    FILE* outfile = fopen("generations.txt", "a");
    printHeader(outfile);

    // esiste una popolazione parzialmente salvata??
    Population loadedPop = new Population(nIndividuals);
    if(!loadedPop.load("population.dat"))
    {
        writefln("growing a new population from start");
        initPop.grow(of1, minGrowDepth, maxGrowDepth, maxGrowNodes, growTerminationProbability);
    }
    else
    {
        writefln("found a partial saved population of %d individual", loadedPop.individuals.length);
        // la popolazione salvata e' sempre un sottoinsieme della popolazione totale
        scope Population fillerPop = new Population(nIndividuals - loadedPop.individuals.length);
        fillerPop.grow(of1, minGrowDepth, maxGrowDepth, maxGrowNodes, growTerminationProbability);
        assert(fillerPop.individuals.length + loadedPop.individuals.length == nIndividuals);
        initPop.individuals = loadedPop.individuals ~ fillerPop.individuals;

//        loadedPop.individuals.length = 0;
//        fillerPop.individuals.length = 0;
//        loadedPop = null;
//        fillerPop = null;

        // delete fillerPop;
    }


    // test semplificazione
    {

        scope Individual[3000] simplers;
        foreach(i, inout s; simplers)
        {
            s = initPop.individuals[i].simplify;
            s.eval(problemRD);
            initPop.individuals[i].eval(problemRD);
            if(s.fitness != initPop.individuals[i].fitness && s.isValid && initPop.individuals[i].isValid && ! isnan(s.fitness) && !isnan(initPop.individuals[i].fitness))
            {
                writefln("fallita semplificazione, i due seguenti dovrebbero essere uguali:\n");
                writefln("%s, fitness = %s\n", s, s.fitness );
                writefln("%s, fitness = %s\n", initPop.individuals[i], initPop.individuals[i].fitness);
                return 1;
            }
        }

    }

    delete loadedPop;

    //fullCollect();

    Population tournamentWinnersPop = new Population(nTournamentWinners);

    Population mutationsPop = new Population(nMutations);
    Population winnersCrossbreedsPop = new Population(nWinnersCrossbreeds);
    Population newIndividualsPop = new Population(nNewIndividuals);



version (diversity)
{
    int [real]countsMap;
    Individual [real]diversityMap;
    Individual[] sortedWinners;
}


    real previousMeanFitness = - 100;


    // solo una parte dei dati viene usata come dataset dal GA per calcolare
    // la fitness e guidare l'evoluzione; il resto viene usato come test per vedere che effettivamente
    // l'errore calcolato "esternamente" sia analogo a quello calcolato sul dataset. Nel momento in cui i due andamenti iniziano a discostarsi,
    // vuol dire che l'algoritmo inizia a classificare e non vale piu' la pena andare avanti (perche' diventa intrinsecamente
    // non lineare e incapace di interpolare).
    real previousBestFitness = - 100;

    // per quante volte consecutive il test sul dataset di controllo ha fallito?
    int nonMonotoneFitnessCount;

    // per quante volte consecutive non e' cambiato il migliore individuo?
    int unchangedBestCount;

    // ecco il loppone:
    int generationCount;
    for(generationCount = 0; generationCount < maxGenerations && continueEvolution; generationCount++)
    {
        writefln("\n\nStart of generation %d -------------------------------------------- %d, time: %s", generationCount, generationCount, std.date.toString(getUTCtime()));
        fwritefln(outfile, "\n\nStart of generation %d -------------------------------------------- %d, time: %s", generationCount, generationCount, std.date.toString(getUTCtime()));

        // giusto per vederla... cosi' controlliamo a vista che sia bella eterogenea
        //if(gen % 30 == 0 && gen != 0)
        //    writefln("Popolazione da valutare:\n%s",initPop);

        writefln("Evaluating population: %d individuals, %d lines to regress", initPop.individuals.length, problemRD.length);
        initPop.eval(problemRD, nParallelThreads);


        Individual best = initPop.individuals[initPop.bestIndividualIdx];
        Individual simplifiedBest = best.simplify();
        simplifiedBest.eval(problemRD);

        void printPopInfo(FILE* f)
        {
            fwritefln(f, "\nBest Individual: %d = %s", initPop.bestIndividualIdx, best);
            fwritefln(f, "\nBest Individual (simplified): %s", simplifiedBest);
            fwritefln(f, "\nBest Individual Nodes Count: %d - Best Individual Fitness: %f", best.nodesCount, best.fitness);
            fwritefln(f, "Best Individual Error Range: %s", best.errorRange);
            fwritefln(f, "Best Individual Mean Error: %f", best.totalError / problemRD.length);
            fwritefln(f, "Best Individual RMS: %f", best.rms);
            fflush(f);
        }

        printPopInfo(outfile);
        printPopInfo(stdout);

        // siamo arrivati alla fine della possibile evoluzione??
        // controllo se ci sono stati match perfetti:
        if(! continueEvolution)
        {
            writefln("Perfect Match Found. Stopping");
            fwritefln(outfile, "Perfect Match Found. Stopping");
            printPopInfo(outfile);
            printPopInfo(stdout);
            break;
        }

        if(initPop.bestIndividualIdx == 0)
        {
            unchangedBestCount++;
            writefln("Warning: unchanged best individual since %d generations...", unchangedBestCount);
        }

        if(unchangedBestCount >= 25)
        {
            // direi che dopo tot giri che non cambia nulla posso dargliela su
            writefln("Unchanged best since %d generations. Stopping.", unchangedBestCount);
            fwritefln(outfile, "Unchanged best since %d generations. Stopping.", unchangedBestCount);
            printPopInfo(outfile);
            printPopInfo(stdout);
            break;
        }

        // calcolo la fitness del best sul set di dati di controllo
        if(testRD)
        {
            best.forceEvaluation;
            best.eval(testRD);
            writefln("Best Individual RMS on Test DataSet: %f", best.rms);
            writefln("Best Individual Fitness on Test DataSet: %f", best.fitness);

            if(best.fitness < previousBestFitness)
            {
                nonMonotoneFitnessCount++;
                writefln("Warning: non monotone test fitness detected...");
            }
            else
            {
                nonMonotoneFitnessCount = 0;
            }

            if(nonMonotoneFitnessCount > 2)
            {
                // stop. il check sui dati di controllo ha scoperto che stiamo iniziando a classificare e a perdere di linearita'.
                // non vale piu' la pena andare avanti.
                writefln("Non-monotonous fitness on test dataset. Stopping.");
                fwritefln(outfile, "Non-monotonous fitness on test dataset. Stopping.");
                printPopInfo(outfile);
                printPopInfo(stdout);
                break;
            }

            best.forceEvaluation;
        }

        // vado avanti
        previousBestFitness = best.fitness;

        writefln("\nMutations!");
        // genero le mutazioni
        for(int mutCount = 0; mutCount < nMutations; mutCount++)
        {
            mutationsPop.individuals[mutCount] = best.mutate(of1, 2.0 / best.nodesCount);
            //writefln(tournamentWinnersPop.individuals[mutCount]);
        }

        writefln("Tournament!");

        // il migliore passa per default
//        tournamentWinnersPop.individuals[0] = best;
//        tournamentWinnersPop.individuals[1] = simplifiedBest;


        // il torneo funziona cosi':
        // siccome voglio EVITARE che ogni tanto ci siano dei crolli nella fitness media,
        // mantengo il valore della fitness media del giro precedente e faccio in modo che a ogni giro il torneo sia
        // pilotato in modo da farla salire...

version (oldTournament)
{
        real totalFitness = 0;
        // genero i vincitori di torneo
        for(int nic = 0; nic < nTournamentWinners; nic++)
        {
            real fitness = real.min;
            int bestFitnessIdx = -1;
            for(int i = 0; i < tournamentSize || bestFitnessIdx == -1; i++)
            {
                int randomIdx = rand() % initPop.individuals.length;

                // cambiando il seguente IF e utilizzanzo gli errors, gli scaledErrors o i rootMeanSquares si cambia
                // la metrica di tutta la faccenda. ma direi che usare l'RMS modulato col numero di nodi e' l'UOVO DI COLOMBO...
                if(initPop.individuals[randomIdx].fitness > fitness)
                {
                    fitness = initPop.individuals[randomIdx].fitness;
                    bestFitnessIdx = randomIdx;
                }
            }

            // ora ho il migliore di N individui presi a cazzo.
            Individual winner = initPop.individuals[bestFitnessIdx];
            //writefln("individuo vincitore: %d : %s", lowestErrorIdx, best);
            // compilo la nuova popolazione con questi individui che vincono il torneo
            tournamentWinnersPop.individuals[nic] = winner;
//            winner.tournamentWins++;

            assert(std.math.isfinite(fitness));
            totalFitness += fitness;
        }

        real meanFitness = totalFitness / tournamentWinnersPop.individuals.length;
}

version(newTournament)
{
        real meanFitness;

        // per ogni vincitore di torneo...
        for(int tournamentWinnerIdx = 0; tournamentWinnerIdx < nTournamentWinners; tournamentWinnerIdx++)
        {

            // faccio un primo giro:
            real fitness = -real.max;
            int bestFitnessIdx = -1;
            real meanFitnessNow = previousMeanFitness - 0.5;

            for(int retry = 0; retry < 100 && meanFitnessNow < previousMeanFitness + 0.5; retry++)
            {
                for(int i = 0; i < tournamentSize || bestFitnessIdx == -1; i++)
                {
                    int randomIdx = rand() % initPop.individuals.length;

                    if(initPop.individuals[randomIdx].fitness > fitness)
                    {
                        fitness = initPop.individuals[randomIdx].fitness;
                        bestFitnessIdx = randomIdx;
                    }
                }

                // il girello e' stato sufficiente a garantirmi una fitness media monotonamente crescente?
                Individual winner = initPop.individuals[bestFitnessIdx];
                assert(std.math.isfinite(winner.fitness));
                tournamentWinnersPop.individuals[tournamentWinnerIdx] = winner;
                winner.tournamentsWins++;

                meanFitness = meanFitnessNow = tournamentWinnersPop.getMeanFitness(tournamentWinnerIdx+1);
            }

        }


 }

        // QUESTA popolazione vale la pena di salvarla, non quella totale con dentro meta' dei coglioni generati a caso...
        // e' in questa che c'e' il DNA bbuono...
        tournamentWinnersPop.save("population.dat");
        previousMeanFitness = meanFitness;


version (diversity)
{
        // calcoliamo la diversita'
        assert(diversityMap.length == 0);
        assert(countsMap.length == 0);

        for(int i = 0; i < nTournamentWinners; i++)
        {
            countsMap[tournamentWinnersPop.individuals[i].fitness]++;
            diversityMap[tournamentWinnersPop.individuals[i].fitness] = tournamentWinnersPop.individuals[i];
        }

        assert(diversityMap.length == countsMap.length );

        writefln("Tournament Winners Mean Fitness: %f, diversity: %d species, %f%%", meanFitness, diversityMap.length, diversityMap.length /cast(float) nTournamentWinners);


        // becchiamoci tutti e soli gli individui diversi, ordinati per fitness
        writefln("\n****** Hall of Fame ******");
        sortedWinners = diversityMap.values.sort;
        for(int i = 0; i < 3; i++)
        {
            writefln("%d -- (%s):\nfitness %f, presence count %d\n", i, sortedWinners[i], sortedWinners[i].fitness, countsMap[sortedWinners[i].fitness]);
        }
        writefln("**************************\n");

        diversityMap = diversityMap.init;
        countsMap = countsMap.init;
}

        // dai vincitori del torneo genero i crossbreed
        writefln("Crossbreeding!");
        for(int nic = 0; nic < nWinnersCrossbreeds; nic++)
        {
            Individual son;

            int randomWinner1 = rand() % tournamentWinnersPop.individuals.length;
            int randomWinner2;
            while ((randomWinner2 = rand() % tournamentWinnersPop.individuals.length) == randomWinner1) {};

//            crossover(tournamentWinnersPop.individuals[randomWinner1], tournamentWinnersPop.individuals[randomWinner2], son, minGrowNodes, cast(int)(maxGrowNodes / 1.2) );
            crossover(tournamentWinnersPop.individuals[randomWinner1], tournamentWinnersPop.individuals[randomWinner2], son, minGrowNodes, maxGrowNodes);

            winnersCrossbreedsPop.individuals[nic] = son;

            if(nic % (nWinnersCrossbreeds / 10) == 0)
            {
                writef("..%d%%..", nic * 100 / nWinnersCrossbreeds);
                dout.flush();
            }

        }

        writefln("..100%%!");

        // infine, ecco i nuovi arrivati:
        newIndividualsPop.grow(of1, minGrowDepth, maxGrowDepth, maxGrowNodes, growTerminationProbability);

        // QUESTO E' BACATO!
        //initPop.individuals = mutationsPop.individuals ~ winnersCrossbreedsPop.individuals ~ newIndividualsPop.individuals;

        writefln("Assembling new population to evaluate...");
        initPop.individuals[0 .. mutationsPop.individuals.length] = mutationsPop.individuals;
        initPop.individuals[mutationsPop.individuals.length .. mutationsPop.individuals.length + winnersCrossbreedsPop.individuals.length] = winnersCrossbreedsPop.individuals;
        initPop.individuals[mutationsPop.individuals.length + winnersCrossbreedsPop.individuals.length .. mutationsPop.individuals.length + winnersCrossbreedsPop.individuals.length + newIndividualsPop.individuals.length] = newIndividualsPop.individuals;

        // largo al re!
        //initPop.individuals[0] = best;
        //initPop.individuals[0] = simplifiedBest;

        // buttiamoci dentro anche un po' di vincitori di torneo... e' inutile perderli cosi'
version (diversity)
{
        for(int hof = 0; hof < sortedWinners.length / 20; hof++)
        {
            initPop.individuals[hof * 2] = sortedWinners[hof];
        }

        sortedWinners.length = 0;
}

        // garbage collection.. chiamarla esplicitamente non fa male.

        //fullCollect();
        //minimize();
        std.gc.GCStats stats;
        getStats(stats);
        printf("GC Info: Poolsize = %d, Usedsize = %d, Freelistsize = %d\n", stats.poolsize, stats.usedsize, stats.freelistsize);
        //printf("freeblocks = %d, pageblocks = %d\n", stats.freeblocks, stats.pageblocks);

    }

    writefln("End of evolution detected at generation %d", generationCount);
    fwritefln(outfile, "End of evolution detected at generation %d", generationCount);


    return 0;
}




