
import std.stdio;
import std.stream;
import std.cstream;

//import aaron.thread;
import std.thread;

import std.math;
version(Windows) import std.c.windows.windows;
import std.date;
import std.cpuid;
import std.gc;
import std.file;
import std.c.time;

import individual;
import operators;
import regressiondata;
import main;


version = parallelEvaluation;
version = simpleFitness;

version(darwin) extern(C) int pthread_detach(void*);


class Population
{
    this(uint nIndividuals)
    {
        individuals.length = nIndividuals;
//        foreach(inout individual; individuals)
//            individual = new Individual;

        // fitnesses.length = nIndividuals;
    }

//    this()
//    {
//    }

    // valuta tutti gli individui sullo stesso set di valori passato
    // e calcola per ognuno l'errore
    // side effect: trova gli indici dei due individui
    // che approssimano meglio e peggio questo target con i parametri dati
    // lo fa su una riga PRECISA di dati, quindi probabilmente e' una funzione che non useremo mai..
version(unused)
{
    void eval(real[] values)
    {

        // se la usi, controllala perche' non e' up-to-date
        assert(0);

        globalMaxError = -real.max;
        globalMinError = real.max;

        //bestIndividualMaxError = real.min;
        //bestIndividualMinError = real.max;

        maxErrorIdx = -1;
        minErrorIdx = -1;

        //errorsSum = 0;

        foreach(i, individual; individuals)
        {
            real error = individual.evalRowError(values);
            errors[i] = error;
            //errorsSum += error;

            if(error < globalMinError)
            {
                globalMinError = error;
                minErrorIdx = i;
                //bestIndividualMinError = individual.minError;
                //bestIndividualMaxError = individual.maxError;
            }

            if(error > globalMaxError)
            {
                globalMaxError = error;
                maxErrorIdx = i;
            }
        }

        assert(errors[minErrorIdx] == globalMinError);
        assert(errors[maxErrorIdx] == globalMaxError);

    }
}


    class Evaluator : Thread
    {

        this(int idx, RegressionData _rd)
        {
            assert(idx >= 0);
            individualIdx = idx;
            individual = individuals[individualIdx];
            assert(individual !is null);
            rd = _rd;
        }

        int run()
        {
            //writefln("start eval %d", individualToEvaluate);
//            writefln("running evaluators = %d", nRunningEvaluators);
            individual.eval(rd);
            synchronized
            {
                //nodesCount[individualToEvaluate] = individuals[individualToEvaluate].nodesCount;
                if(individual.nodesCount > maxNodes)
                    maxNodes = individual.nodesCount;

                //errors[individualToEvaluate] = individuals[individualToEvaluate].totalError;
                //rootMeanSquares[individualToEvaluate] = individuals[individualToEvaluate].rms;

                if(individual.fitness >  bestIndividualFitness)
                {
                    bestIndividualFitness = individual.fitness;
                    bestIndividualIdx = individualIdx;
                    writef("*(%d:%f)!", bestIndividualIdx, bestIndividualFitness);
                }
            }

            return 0;

            //writefln("end eval %d", individualToEvaluate);
        }

        int individualIdx;
        Individual individual;
        RegressionData rd;

    }

    // valuta tutti gli individui su tutti i valori
    // e calcola per ognuno la somma di tutti gli errori su tutti i valori
    // side effect: trova gli indici del migliore e peggiore individuo
    // che approssimano questi valori
    void eval(RegressionData regressionData, int nParallelThreads)
    {

        //globalMaxError = real.min;
        bestIndividualFitness = - real.max;

        //worstIndividualIdx = -1;
        bestIndividualIdx = -1;

        maxNodes = -int.max;

        auto starttime = getUTCtime();
        Evaluator[] evaluators;
        evaluators.length = nParallelThreads;
        int evaluatorsFreeSpaceIdx;

        foreach(i, individual; individuals)
        {


version(parallelEvaluation)
{

            Evaluator e;

            try
            {
                e = new Evaluator(i, regressionData);
            }
            catch(Exception ex)
            {
                writefln("si e' imballato sulla new");
            }

            //e.setPriority(Thread.PRIORITY.CRITICAL);

            assert(evaluatorsFreeSpaceIdx >= 0 && evaluatorsFreeSpaceIdx < evaluators.length);
            //writefln("evaluator individuo %d assegnato a slot %d", i, evaluatorsFreeSpaceIdx);
            evaluators[evaluatorsFreeSpaceIdx] = e;

            try
            {
                //writefln("start evaluator individuo %d", i);
                e.start();
            }
            catch(Exception ex)
            {
                writefln("Start evaluator individuo %d exception catched: %s", i, ex.msg);
                writefln("was allocated to slot %d", evaluatorsFreeSpaceIdx);
                writefln(individual);
                writefln(individuals[i]);

                e = evaluators[evaluatorsFreeSpaceIdx] = null;
                //fullCollect();
                individuals[i].totalError = real.max;
            }

            // vedo se fermarmi e aspettare che qualcuno finisca e deallocare

            do
            {

                // version(Windows) Sleep(1);

                //writefln("cerco uno slot libero");
                evaluatorsFreeSpaceIdx = -1;
                // contiamo quanti slot libri abbiamo
                foreach(ei, inout evaluator; evaluators)
                {
                    if(evaluator is null)
                    {
                        evaluatorsFreeSpaceIdx = ei;
                        //writefln("slot libero:%d", evaluatorsFreeSpaceIdx);
                        break;
                    }
                    else if(evaluator.getState() == Thread.TS.TERMINATED)
                    {
                        //writefln("evaluator individuo %d terminato, indice %d, chiamo delete", evaluator.individualToEvaluate, ei);
                        assert(evaluator == evaluators[ei]);
                        // BACO IN PHOBOS!! NON VIENE FATTA LA CloseHandle sul thread incapsulato da Thread
                        // la mia versione l'ho messa dentro phobos
                        // thread.d:418
                        // version(Windows) CloseHandle(evaluator.hdl);
                        version(darwin) pthread_detach(evaluator.id);
                        // la seguente delete
                        //delete evaluator;
                        //writefln("chiamata delete");
                        evaluatorsFreeSpaceIdx = ei;
                        evaluators[evaluatorsFreeSpaceIdx] = null;
                        evaluator = null;
                        //writefln("slot libero:%d", evaluatorsFreeSpaceIdx);
                        break;
                    }
                }

            }
            while(evaluatorsFreeSpaceIdx == -1);


}

version(singleEvaluation)
{
            individuals[i].evalTotalError(regressionData);

            //nodesCount[individualToEvaluate] = individuals[individualToEvaluate].nodesCount;
            if(individuals[i].nodesCount > maxNodes)
                maxNodes = individuals[i].nodesCount;

            //errors[individualToEvaluate] = individuals[individualToEvaluate].totalError;
            //rootMeanSquares[individualToEvaluate] = individuals[individualToEvaluate].rms;

            if(individuals[i].totalError < globalMinError)
            {
                globalMinError = individuals[i].totalError;
                bestIndividualIdx = i;
            }

            if(individuals[i].totalError > globalMaxError)
            {
                globalMaxError = individuals[i].totalError;
                worstIndividualIdx = i;
            }

}


            if(i % (individuals.length / 20) == 0)
            {
                writef(".%d%%.", i * 100 / individuals.length);
                dout.flush();
                //fullCollect();
            }
        }


        // aspettiamo che finiscano tutti

        do
        {
            evaluatorsFreeSpaceIdx = 0;
            foreach(evaluator; evaluators)
            {
                if(evaluator !is null && evaluator.getState() != Thread.TS.TERMINATED)
                {
                    evaluatorsFreeSpaceIdx = -1;
                }
            }
        }
        while(evaluatorsFreeSpaceIdx == -1);


        auto elapsed = getUTCtime() - starttime;

        writefln("..100%%!\nEvaluation time = %d.%03d seconds",
		cast(int) (elapsed / TicksPerSecond),
		cast(int) (elapsed % TicksPerSecond));


        // provo a scalare l'errore in base alla complessita'. non e' facile.
        // voglio dare la priorita' a individui piu' semplici

        for(int i = 0; i < individuals.length; i++)
        {
            if(individuals[i].totalError == -1)
            {
                writefln("non inizializzato individuo %d", i );
                //errors[i] = rootMeanSquares[i] = real.max;
                //nodesCount[i] = maxNodes - 1;
                individuals[i].totalError = individuals[i].rms = real.max;
                individuals[i].nodesCount = maxNodes -1;

            }

//            fitnesses[i] = 1 / (rootMeanSquares[i] / ((maxNodes - nodesCount[i]) * 2 ));
//            fitnesses[i] = 1 / (individuals[i].totalError / ((maxNodes - individuals[i].nodesCount) * 2 ));
            if(individuals[i].rms == 0)
            {
                //writefln("FOUND PERFECT MATCH, RMS = 0");
                //writefln("Individual: %s", individuals[i]);
                main.continueEvolution = false;
            }

            //assert( ! std.math.isnan(fitnesses[i]));
        }

        assert(bestIndividualIdx == -1 || individuals[bestIndividualIdx].fitness == bestIndividualFitness);
        //assert(worstIndividualIdx == -1 || individuals[worstIndividualIdx].totalError == globalMaxError);

    }


    void grow(OperatorsFactory of, int minDepth, int maxDepth, int maxNodes, float terminationProbability)
    {
        writefln("Growing...");
        foreach(i, inout individual; individuals)
        {
            individual = new Individual;
            individual.grow(of, minDepth, maxDepth, maxNodes, terminationProbability);
            if(i % (individuals.length / 10) == 0)
            {
                writef("..%d%%..", i * 100 / individuals.length);
                dout.flush();
            }
        }

        writefln("..100%%!");
    }

    /*
    char[] toString()
    {
        char[] ret;
        foreach(i, individual; individuals)
        {
            ret ~= ( std.string.toString(i) ~ ") ");
            ret ~= individual.toString();
            ret ~= "\n";
        }

        return ret;
    }
*/

/*
    void clear()
    {
        individuals.length = 0;
        fitnesses.length = 0;
    }

    void opCatAssign(Population other)
    {
        individuals ~= other.individuals;
        fitnesses ~= other.fitnesses;
    }

    void opCatAssign(Individual other)
    {
        individuals ~= other;
        fitnesses.length = fitnesses.length + 1;
    }

    uint length()
    {
        return individuals.length;
    }
*/


    void save(char[] filename)
    {
        writefln("Saving population...");
        if(exists(filename))
        {
            if(exists(filename ~ ".bak"))
                std.file.remove(filename ~ ".bak");

            std.file.rename(filename, filename ~ ".bak");
        }

        File f = new File(filename, FileMode.OutNew);

        //if(! isfinite(globalMaxError) || isnan(globalMaxError)) globalMaxError = real.max;
        if(! isfinite(bestIndividualFitness) || isnan(bestIndividualFitness)) bestIndividualFitness = - real.max;

//        f.writef("%s %s %s %s %s %s\n", globalMaxError, globalMinError, worstIndividualIdx, bestIndividualIdx, maxNodes, individuals.length);
        f.writef("%s %s %s %s\n", bestIndividualFitness, bestIndividualIdx, maxNodes, individuals.length);

        foreach(i, individual; individuals)
        {
            individual.save(f);
            f.writefln();

            if(i % (individuals.length / 10) == 0)
            {
                writef(".%d%%.", i * 100 / individuals.length);
                dout.flush();
            }

        }

/*
        assert(fitnesses.length == individuals.length);

        f.writef("%s ", fitnesses.length);
        foreach(value; fitnesses)
        {
            if(! isfinite(value) || isnan(value)) value = real.max;
            f.writef("%s ", value);
        }
*/

        writefln(".100!");

        f.close();

    }

    bool load(char[] filename)
    {

        if(!exists(filename))
            return false;

        writefln("Loading population...");
        File f = new File(filename);

        int individualsLength;
        f.readf(&bestIndividualFitness, &bestIndividualIdx, &maxNodes, &individualsLength);

        individuals.length = individualsLength;

        foreach(i, inout individual; individuals)
        {
            individual = new Individual;
            individual.load(f);

            if(i % (individuals.length / 10) == 0)
            {
                writef(".%d%%.", i * 100 / individuals.length);
                dout.flush();
            }
        }

/*
        int fitnessesLength;
        f.readf(&fitnessesLength);
        fitnesses.length = fitnessesLength;

        foreach(inout value; fitnesses)
            f.readf(&value);
*/

        writefln(".100!");

        f.close();
        return true;
    }

    // calcola la fitness media sui primi N individui
    real getMeanFitness(int nIndividuals)
    {
        real totalFitness = 0;
        for(int i = 0; i < nIndividuals; i++)
            totalFitness += individuals[i].fitness;

        totalFitness /= nIndividuals;
        return totalFitness;
    }




    Individual[] individuals;

    // i seguenti valori di errore si riferiscono a una valutazione di tutta la popolazione su
    // UNA SOLA RIGA del dataset oppure TUTTO il dataset a seconda che si chiami la eval su una sola riga o su tutto
    // il dataset. In ogni caso abbiamo l'errore di ogni individuo (su una riga o totale su tutte) e gli indici del
    // migliore e peggiore individuo

    // errori assoluti massimi e minimi.
    //real globalMaxError = real.min;
    //real globalMinError = real.max;

//    real bestIndividualMaxError = real.min;


    // indici degli individui che hanno maggiore e minore errore.
    //int worstIndividualIdx = -1;
    int bestIndividualIdx = -1;

    // usato dai vari thread, e' una variabile sincronizzata
    real bestIndividualFitness = - real.max;

    int maxNodes = int.min;

    // errori degli individui.
    //real[] errors;
    //real[] fitnesses;
    //real[] rootMeanSquares;
    //int[] nodesCount;

    //RegressionData regressionData;
    //uint nParallelThreads;

}
