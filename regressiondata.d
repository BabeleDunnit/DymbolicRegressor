

import std.stdio;
import std.stream;
import std.string;
import std.math;
import std.random;
import std.file;

import individual;
import rangedetector;

class RegressionData
{

    bool readData(char[] fileName)
    {
        if(!exists(fileName))
        {
            writefln("Cannot open regress data file <%s>", fileName);
            return false;
        }

        writefln("Reading data file to regress: <%s>", fileName);
        // faccio un primo giro per contare linee e dimensioni...

        Stream file = new BufferedFile(fileName);

        int nLinesToRegress;
        int nDimensions;
        bool firstPass = true;
        foreach(ulong lineNum, char[] line; file)
        {
            //writefln("line %d: %s",lineNum,line);
            char[][] values = std.string.split(line);
            int dims = values.length;

            if(firstPass)
            {
                nDimensions = dims;
            }
            else
            {
                if(dims != nDimensions)
                {

                    writefln("Line %d: wrong dimension of data", lineNum);
                    throw new Error("wrong dimension of data");
                }
            }

            firstPass = false;

            nLinesToRegress++;
        }

        file.close();

        // ... ed ora che lo abbiamo girato, allochiamo i vettori della dimensione giusta, lo riapriamo e leggiamo i valori...
        // il D e' TROPPO veloce...

        file = new BufferedFile(fileName);

        rangeDetectors.length = nDimensions;
        foreach(inout d; rangeDetectors)
//            d = new RealRangeDetector;
            d = new RangeDetector!(real);

        valuesToRegress.length = nLinesToRegress;
        foreach(ulong lineNum, char[] line; file)
        {
            //writefln("line %d: %s",lineNum-1,line);
            valuesToRegress[lineNum-1].length = nDimensions;
            char[][] values = std.string.split(line);
            foreach(valueIdx, char[] val; values)
            {
                real v = atof(val);
                rangeDetectors[valueIdx] = v;
                valuesToRegress[lineNum-1][valueIdx] = v;
            }

        }

        file.close();

        version(vecchio)
        {
        nDimensions--;
        writefln("Done. Lines to regress: %d, dimensions of problem: %d", nLinesToRegress, nDimensions);
        }


        writefln("Done. Lines to regress: %d, dimensions of problem: %d", length, dimensions);

        return true;
    }

    void generateTestFile(char[] filename)
    {

        writefln("Generating regress data file <%s>", filename);
        Stream testfile = new BufferedFile(filename, FileMode.Out);

        int fitnessCases = 40;
        for(int i = 0; i < fitnessCases; i++)
        {
            float range = 3.14;
            float start = 0;
            float x = start + ((range / cast(float) fitnessCases) * i );
            // ecco la funzione da cuccare:
            float f = sin(x + 0.4 + sin( 0.7 - x ));
            testfile.writefln("%f  %f", x, f);
        }

        testfile.close();
    }

    void shuffleLines()
    {
        for(int i = 0; i < valuesToRegress.length * 10; i++)
        {
            int l1 = rand % valuesToRegress.length;
            int l2 = rand % valuesToRegress.length;

            auto temp = valuesToRegress[l1];
            valuesToRegress[l1] = valuesToRegress[l2];
            valuesToRegress[l2] = temp;
        }
    }

    void more(int nLines)
    {
        for(int i = 0; i < nLines; i++)
            writefln(valuesToRegress[i]);
    }

    uint length()
    {
        return valuesToRegress.length;
    }

    uint dimensions()
    {
        return valuesToRegress[0].length - 1 ;
    }


    RegressionData split(int nLines)
    {
        int oriLen = length;
        RegressionData other = new RegressionData;
        other.valuesToRegress = valuesToRegress[0..nLines];
        auto temp = valuesToRegress[nLines..$];
        valuesToRegress = temp;

        assert(other.length == nLines);
        assert(length == oriLen - other.length);

        // invalidiamo i rangeDetectors;
        //rangeDetectors.length = 0;
        updateRangeDetectors;
        other.updateRangeDetectors;

        return other;
    }

    void updateRangeDetectors()
    {
        rangeDetectors.length = dimensions + 1;
        foreach(inout d; rangeDetectors)
            d = new RangeDetector!(real);

        foreach(line; valuesToRegress)
        {
            foreach(i, val; line)
            {
                rangeDetectors[i] = val;
            }

        }
    }




    //uint nLinesToRegress;
    //uint nDimensions;
    real[][] valuesToRegress;


    //typedef RangeDetector!(real) RRangeDetector;
    //RRangeDetector[]  rangeDetectors;
    RangeDetector!(real)[] rangeDetectors;
    //RealRangeDetector[] rangeDetectors;

}

