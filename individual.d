
import std.random;
import std.stdio;
import std.math;
import std.stream;
import std.conv;

import operators;
import regressiondata;
import rangedetector;

version = simpleFitness;


float randFloat()
{
    float ret =  ((cast(float) rand()) / uint.max);
    assert(ret >= 0 && ret <= 1);
    return ret;
}

class Node
{

    void setOperator(Operator o)
    {
        /*
        children.length = o.arity;
        foreach(inout child; children)
            child = new Node;
            */

        operator = o;
        for(int i = 0; i < operator.arity; i++)
            children[i] = new Node;

    }

    Operator getOperator()
    {
        return operator;
    }

    void grow(OperatorsFactory of, int minDepth, int maxDepth, int maxNodes, float terminationProbability)
    {
        assert(minDepth < maxDepth);
        if( (maxNodes < 2) || (maxDepth == 1) || (randFloat() <  terminationProbability && minDepth <= 1))
        {
            setOperator(of.makeRandomTerminal());
        }
        else
        {
            setOperator(of.makeRandomOperator());
//            foreach(inout child; children)
//            {
//                child.grow(of, minDepth - 1, maxDepth - 1, maxNodes - 2, terminationProbability);
//                maxNodes -= child.countChildren();
//            }
            for(int i = 0; i < operator.arity; i++)
            {
                children[i].grow(of, minDepth - 1, maxDepth - 1, maxNodes - 2, terminationProbability);
                maxNodes -= children[i].countChildren();
            }
        }

    }

    char[] toString()
    {
        char[][] childrenStrings;
//        childrenStrings.length = children.length;
        childrenStrings.length = operator.arity;

        // stringizzo i figli
        foreach(i, inout s; childrenStrings)
            s = children[i].toString;

        assert(operator);
        // e li passo all'operatore che si stampa opportunamente
        char[] toReturn = operator.toString(childrenStrings);

        // questa roba qui non dovrebbe servire a nulla se il GC funge davvero..
        foreach(i, inout s; childrenStrings)
            s = childrenStrings[i] = null;
        childrenStrings.length = 0;
        childrenStrings = null;


        return toReturn;
    }

    real eval(real[] params)
    {
        return operator.eval(children, params);
    }

    void recursiveMutate(OperatorsFactory of, real prob)
    {
        assert(prob >= 0 && prob <= 1);
        if(randFloat() < prob)
        {
            int arity = operator.arity;
            if(arity == 0)
            {
                Constant constantOperator = cast(Constant) operator;
                if( constantOperator !is null && randFloat() < 0.3)
                {
                    constantOperator.applyDelta();
                }
                else
                {
                    operator = of.makeRandomTerminal();
                }
            }
            else
                do
                {
                    operator = of.makeRandomOperator();
                }
                while(operator.arity != arity);

        }

//        foreach(child; children)
        for(int i = 0; i < operator.arity; i++)
            children[i].recursiveMutate(of, prob);
    }


    void recursiveSimplify()
    {

        //writefln("entro");
        for(int i = 0; i < operator.arity; i++)
//        foreach(i, child; children)
        {
            //writefln("chiamo ricorsivamente sul figlio %d", i);
            children[i].recursiveSimplify();
        }

        // risalgo se sono dentro una variabile o una costante
        if(operator.arity == 0)
        {
            //writefln("operator arity == 0, risalgo");
            return;
        }

        //writefln("operator arity != 0 (in effetti e' %d)", operator.arity);

        // se i figli son costanti, posso trasformare me stesso in una costante
        //writefln("guardo se i figli son tutti costanti");
        int constantChildrenCount;
        int variableChildrenCount;
        for(int i = 0; i < operator.arity; i++)
//        foreach(child; children)
        {
            if( (cast(Constant) children[i].operator) !is null)
            {
                constantChildrenCount++;
                //writefln("trovato figlio costante, constantChildrenCount = %d", constantChildrenCount);
            }

            if( (cast(Variable) children[i].operator) !is null)
            {
                variableChildrenCount++;
                //writefln("trovato figlio costante, constantChildrenCount = %d", constantChildrenCount);
            }
        }

        //writefln("numero figli costanti: %d", constantChildrenCount);
        if(constantChildrenCount == operator.arity)
        {
            // tutti i miei figli sono costanti... semplifico

            // calcolo il valore
            real[] dummyParams;
            real newValue = operator.eval(children, dummyParams);

            // mi trasformo in costante

            // secchiamo via i figli
            //children.length = 0;
            foreach(inout c; children)
                c = null;

            Constant newConstant = new Constant;
            newConstant.value = newValue;
            operator = newConstant;

            return;
        }

        if(variableChildrenCount == 2)
        {
            // tutti i miei figli sono variabili... posso semplificare qualcosa?

            // se non e' la stessa variabile, niente da fare...
            if( (cast(Variable) children[0].operator).index != (cast(Variable) children[1].operator).index)
                return;

            real newValue;
            if( (cast(Sub) operator) !is null)
            {
                newValue = 0;
            }
            else
            if( (cast(Div) operator) !is null)
            {
                newValue = 1;
            }

            if(! isnan(newValue))
            {
            // mi trasformo in costante

            // secchiamo via i figli
            //children.length = 0;
            foreach(inout c; children)
                c = null;

            Constant newConstant = new Constant;
            newConstant.value = newValue;
            operator = newConstant;

            return;
            }
        }

        // casi tipo X * 1, X * 0, X + 0 etc
        if(constantChildrenCount == 1 && variableChildrenCount == 1)
        {
            // questa roba potrebbe finire sopra e diventare piu' generica
            Node variableChild;
            Node constantChild;

            if( (cast(Variable) children[0].operator) !is null)
            {
                variableChild = children[0];
                constantChild = children[1];
            }
            if( variableChild is null)
            {
                variableChild = children[1];
                constantChild = children[0];
            }

            assert( cast(Variable) variableChild.operator);
            assert( cast(Constant) constantChild.operator);

            real constantValue = (cast(Constant) constantChild.operator).value;
            if(constantValue != 0 && constantValue != 1)
                return;


            if( (cast(Mult) operator) !is null && constantValue == 1)
            {
                operator = variableChild.operator;
                foreach(inout c; children)
                    c = null;
                return;
            }

            if( (cast(Mult) operator) !is null && constantValue == 0)
            {
                operator = constantChild.operator;
                foreach(inout c; children)
                    c = null;
                return;
            }

            if( (cast(Add) operator) !is null && constantValue == 0)
            {
                operator = variableChild.operator;
                foreach(inout c; children)
                    c = null;
                return;
            }

            if( (cast(Div) operator) !is null && constantValue == 1 && variableChild == children[0])
            {
                operator = variableChild.operator;
                foreach(inout c; children)
                    c = null;
                return;
            }


        }



    }


    unittest
    {
        // Test figli costanti
        {
        Node n = new Node;
        n.operator = new Sub;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[0].operator = new Constant;
        n.children[1].operator = new Constant;
        real r = (cast(Constant) n.children[0].operator).value;
        (cast(Constant) n.children[1].operator).value = r;
        assert(n.operator.classinfo.name == "operators.Sub");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Constant");
        assert((cast(Constant) n.operator).value == 0);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }

        // funziona anche ricorsivamente??
        {
        Node sub = new Node;
        sub.operator = new Sub;

        Node cons1 = new Node;
        cons1.operator = new Constant;

        Node mult = new Node;
        mult.operator = new Mult;

        Node cons2 = new Node;
        cons2.operator = new Constant;

        Node cons3 = new Node;
        cons3.operator = new Constant;

        (cast(Constant) cons1.operator).value = 0.5;
        (cast(Constant) cons2.operator).value = 0.6;
        (cast(Constant) cons3.operator).value = 0.7;

        // (  0.5 - ( 0.6 * 0.7 ))
        sub.children[0] = cons1;
        sub.children[1] = mult;

        mult.children[0] = cons2;
        mult.children[1] = cons3;

        assert(sub.operator.classinfo.name == "operators.Sub");
        sub.recursiveSimplify;
        assert(sub.operator.classinfo.name == "operators.Constant");
        assert(feqrel((cast(Constant) sub.operator).value, 0.08) > 60);
        assert(sub.children[0] is null);
        assert(sub.children[1] is null);
        }

        // semplifichiamo una sottrazione di due variabili uguali
        {
        Node n = new Node;
        n.operator = new Sub;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[0].operator = new Variable;
        n.children[1].operator = new Variable;
        (cast(Variable) n.children[0].operator).index = 0;
        (cast(Variable) n.children[1].operator).index = 0;
        assert(n.operator.classinfo.name == "operators.Sub");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Constant");
        assert((cast(Constant) n.operator).value == 0);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }

        // semplifichiamo una divisione di due variabili uguali
        {
        Node n = new Node;
        n.operator = new Div;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[0].operator = new Variable;
        n.children[1].operator = new Variable;
        (cast(Variable) n.children[0].operator).index = 0;
        (cast(Variable) n.children[1].operator).index = 0;
        assert(n.operator.classinfo.name == "operators.Div");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Constant");
        assert((cast(Constant) n.operator).value == 1);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }

        // semplifichiamo X * 1
        {
        Node n = new Node;
        n.operator = new Mult;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[0].operator = new Variable;
        n.children[1].operator = new Constant;
        (cast(Variable) n.children[0].operator).index = 0;
        (cast(Constant) n.children[1].operator).value = 1;
        assert(n.operator.classinfo.name == "operators.Mult");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Variable");
        assert((cast(Variable) n.operator).index == 0);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }

        // semplifichiamo 1 * X
        {
        Node n = new Node;
        n.operator = new Mult;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[1].operator = new Variable;
        n.children[0].operator = new Constant;
        (cast(Variable) n.children[1].operator).index = 0;
        (cast(Constant) n.children[0].operator).value = 1;
        assert(n.operator.classinfo.name == "operators.Mult");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Variable");
        assert((cast(Variable) n.operator).index == 0);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }


        // semplifichiamo X / 1
        {
        Node n = new Node;
        n.operator = new Div;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[0].operator = new Variable;
        n.children[1].operator = new Constant;
        (cast(Variable) n.children[0].operator).index = 0;
        (cast(Constant) n.children[1].operator).value = 1;
        assert(n.operator.classinfo.name == "operators.Div");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Variable");
        assert((cast(Variable) n.operator).index == 0);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }

        // semplifichiamo X * 0
        {
        Node n = new Node;
        n.operator = new Mult;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[0].operator = new Variable;
        n.children[1].operator = new Constant;
        (cast(Variable) n.children[0].operator).index = 0;
        (cast(Constant) n.children[1].operator).value = 0;
        assert(n.operator.classinfo.name == "operators.Mult");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Constant");
        assert((cast(Constant) n.operator).value == 0);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }

        // semplifichiamo X + 0
        {
        Node n = new Node;
        n.operator = new Add;
        n.children[0] = new Node;
        n.children[1] = new Node;
        n.children[0].operator = new Variable;
        n.children[1].operator = new Constant;
        (cast(Variable) n.children[0].operator).index = 0;
        (cast(Constant) n.children[1].operator).value = 0;
        assert(n.operator.classinfo.name == "operators.Add");
        n.recursiveSimplify;
        assert(n.operator.classinfo.name == "operators.Variable");
        assert((cast(Variable) n.operator).index == 0);
        assert(n.children[0] is null);
        assert(n.children[1] is null);
        }

    }


    int countChildren()
    {
        int sum = 0;

        // conto ricorsivamente
//        foreach(child; children)
        for(int i = 0; i < operator.arity; i++)
            sum += children[i].countChildren();

        // aggiungo me stesso
        sum += 1;

        return sum;
    }

    Node getChildAt(inout int idx)
    {

        if(idx == 0)
            return this;

        idx--;

        for(int i = 0; i < operator.arity; i++)
//        foreach(child; children)
        {
            Node n = children[i].getChildAt(idx);
            if (n !is null)
                return n;
        }

        return null;
    }

    void deepCopy(Node n)
    {
        // ecco il baco!!
        //setOperator(n.getOperator);

        Operator myOperator = n.getOperator.clone;
        setOperator(myOperator);

        assert(operator.arity == n.operator.arity);
        for(int i = 0; i < operator.arity; i++)
            children[i].deepCopy(n.children[i]);
    }

    // fa una deepcopy ricorsiva di r, ma quando incontra il nodo "last" lo sostituisce col
    // nodo "first" e continua da li. Serve a passare due nodi appartenenti a due alberi diversi
    // e costruire un albero che e' un crossover dei due
    void deepCopySwitched(Node r, Node last, Node first)
    {

        //writefln("last: %d %s; first: %d %s", cast(void*)last, last, cast(void*)first, first);
        assert( r !is null);

        if(r == last)
        {
            r = first;
            last = null;
        }

        // baco!!
        // setOperator(r.getOperator);

        Operator myOperator = r.getOperator.clone;
        setOperator(myOperator);

        //assert(children.length == r.children.length);
        for(int i = 0; i < operator.arity; i++)
//        foreach(i, inout child; children)
        {
            assert(children[i] !is null);
            children[i].deepCopySwitched(r.children[i], last, first);
        }


//        foreach(inout child; children)
//        {
//            assert(child !is null);
//            child.deepCopySwitched(child, last, first);
//        }
    }

    bool hasVariableNode()
    {
        //writefln(typeid(typeof(this)));
        //writefln(typeid(Variable));

        Variable v = cast(Variable) operator;

        if(v !is null)
            return true;

//        foreach(child; children)
        for(int i = 0; i < operator.arity; i++)
        {
            if(children[i].hasVariableNode())
                return true;
        }

        return false;

    }

    void save(File f)
    {

        operator.save(f);

//        foreach(child; children)
        for(int i = 0; i < operator.arity; i++)
        {
            children[i].save(f);
        }
    }

    void load(File f)
    {

        char[] opToCreate;
        f.readf(&opToCreate);

        Operator opToSet;
        bool isConstant = true;
        real r;

        try
        {
            r = toReal(opToCreate);
        }
        catch(Error e)
        {
            isConstant = false;
        }

        if(isConstant)
        {
            Constant c = new Constant;
            c.value = r;
            opToSet = c;
        }
        else if(opToCreate[0] == 'X')
        {
            int idx = opToCreate[1] - '0';
            Variable v = new Variable(idx);
            opToSet = v;
        }
        else
        {
            opToSet = OperatorsFactory.makeOperator("operators." ~ opToCreate);
        }

        setOperator(opToSet);

//        foreach(inout child; children)
        for(int i = 0; i < operator.arity; i++)
        {
            children[i].load(f);
        }
    }



    private:
    Node[2] children;
    Operator operator;
}


// algoritmo del crossover:
// trovo due nodi, uno in un individuo e uno nell'altro.
// scendo ricorsivamente e faccio una deep copy fino a quando trovo il primo nodo.
// da li' scendo nel secondo e faccio la deepcopy da li in poi
// lascia inalterati i due genitori e crea un nuovo figlio

void crossover(Individual father, Individual mother, inout Individual son, int minNodes, int maxNodes)
{

    assert(father !is null);
    assert(mother !is null);

    Node nf, nm;
    int totalNodes;
    int fatherRootChildrenCount;
    int nTries;
    bool isLongLikeFather;
    bool isLengthInsideBounds;
    do
    {
        father.findRandomNode(nf);
        mother.findRandomNode(nm);

        assert(nf !is null);
        assert(nm !is null);

        fatherRootChildrenCount = father.root.countChildren;
        int nfChildrenCount = nf.countChildren;
        int nmChildrenCount = nm.countChildren;

        totalNodes =  fatherRootChildrenCount - nfChildrenCount + nmChildrenCount;
        nTries++;

        isLongLikeFather = fabs(totalNodes - fatherRootChildrenCount) < (cast(float) totalNodes * 0.2);
        isLengthInsideBounds = minNodes <= totalNodes && totalNodes <= maxNodes;

    }
//    while(totalNodes > maxNodes || totalNodes < minNodes)
//    while( ((fabs(totalNodes - fatherRootChildrenCount) < cast(float) totalNodes * 0.2) && nTries < 5000) || ( nTries >= 5000 && (totalNodes > maxNodes || totalNodes < minNodes)))
//    while( (fabs(totalNodes - fatherRootChildrenCount) < cast(float) totalNodes * 0.2) && nTries < 10000)
//    while( (!isLongLikeFather && nTries < 5000) || (!isLengthInsideBounds && nTries >= 5000));
    while( ! isLengthInsideBounds );


    son = new Individual;
    son.root = new Node;

    son.root.deepCopySwitched(father.root, nf, nm);

    son.updateNodesCount;
    son.updateIsValid;

//    nf = null;
//    nm = null;

}

// la classe individual wrappa un albero di operatori e rappresenta una funzione f(X0, X1... Xn);
class Individual
{

    unittest
    {
    }

    void grow(OperatorsFactory of, int minDepth, int maxDepth, int maxNodes, float terminationProbability)
    {
        //delete root;
        root = null;
        root = new Node;
        root.grow(of, minDepth, maxDepth, maxNodes, terminationProbability);
//        totalError = -1;
//        nodesCount = -1;
        forceEvaluation;
        updateNodesCount;
        updateIsValid;
    }


    this()
    {
//        errorRange = new RealRangeDetector;
        errorRange = new RangeDetector!(real);
    }

    char[] toString()
    {
        assert(root ! is null);
        return root.toString;
    }

/*
    // valuta il valore un individuo/funzione assegnando params[0] a X0, params[1] a X1 etc
    real eval(real[] params)
    {
        //assert(params.length >= operatorsFactory.nVariables);
        // cannot eval a null individual. must grow it
        assert(root ! is null);

        real v = root.eval(params);
        return v;
    }
*/

    // valuta l'errore su una riga di dati. l'ultimo valore passato nel vettore dei parametri e' il valore che
    // si considera corretto, quindi l'individuo puo' avere max params.length - 1 variabili
    real evalRowError(real[] params)
    {
        // assert(params.length == operatorsFactory.nVariables + 1);
        // cannot eval a null individual. must grow it
        assert(root ! is null);

        // non voglio funzioni composte solo da costanti
//        if(!isValid)
//            return real.max;

        real v;
        try
        {
            v = root.eval(params);
        }
        catch(Exception e)
        {
            writefln("evalRowError: si e' incartato nella eval ricorsiva di %s con parametri %s", root, params);
            throw e;
        }

        return abs(v - params[length-1]);
    }


    // errore su tutto il dataset
    // side effect: ricalcola tutti gli errori e gli indici dei massimi e minimi
    void eval(RegressionData regressionData)
    {

        // cannot eval a null individual. must grow it
        assert(root ! is null);

        // e' un vincitore di tornei precedenti che e' gia' stato valutato??
        if(totalError != -1)
            return;

        // non voglio funzioni composte solo da costanti
        if(!isValid)
        {
            totalError = rms = real.max;
            return;
        }

        totalError = rms = 0;
        assert(errorRange);
        errorRange.reset;

        foreach(i, datarow; regressionData.valuesToRegress)
        {
            assert(datarow.length == regressionData.dimensions + 1);

            real err = -1;
            try
            {
                err = evalRowError(datarow);
            }
            catch(Exception e)
            {
                writefln("eval: si e' incartato nella evalRowError di this = %s con parametri %s (riga %d)", this, datarow, i);
                throw e;
            }

            assert( ! (err < 0) );

            totalError += err;
            rms += (err * err);

            // range detection;
            errorRange = err;

/*            if(err < minError)
            {
                minError = err;
            }

            if(err > maxError)
            {
                maxError = err;
            }
*/

        }

        rms /= regressionData.valuesToRegress.length;
        rms = sqrt(rms);

        updateFitness();

        //updateNodesCount();

        //return 0;
    }

    void findRandomNode(inout Node n)
    {
        //updateNodesCount();
        int randomIdx = rand() % nodesCount;

        n = getNode(randomIdx);
        if(n is null)
        {
            writefln("trovato BACONE");
            writefln("this: %s; nodescount: %s", this, nodesCount);
            writefln("randomIdx: %s", randomIdx);
            //n = getNode(randomIdx);
            assert(0);

        }
    }

    void updateNodesCount()
    {
//        if(nodesCount != -1)
//            return;

        nodesCount = root.countChildren();
    }

    Node getNode(int idx)
    {
        return root.getChildAt(idx);
    }

    Individual deepCopy(Individual other)
    {
        root = new Node;
        root.deepCopy(other.root);

        //nodesCount = -1;
        //updateNodesCount();
        //updateIsValid();

        totalError = other.totalError;

//        maxError = other.maxError;
//        minError = other.minError;

        errorRange = other.errorRange;

        rms = other.rms;
        nodesCount = other.nodesCount;
        isValid = other.isValid;

        return this;
    }

    Individual mutate(OperatorsFactory of, real pointMutateProb)
    {
        Individual mutation = new Individual;
        mutation.deepCopy(this);
        mutation.root.recursiveMutate(of, pointMutateProb);
        mutation.forceEvaluation;
        mutation.updateIsValid;
        mutation.updateNodesCount;
        return mutation;
    }

    Individual simplify()
    {
        Individual simpler = new Individual;
        simpler.deepCopy(this);
        simpler.root.recursiveSimplify();
        simpler.forceEvaluation;
        simpler.updateIsValid;
        simpler.updateNodesCount;

//        assert(simpler.nodesCount == -1);
        return simpler;
    }


    void updateIsValid()
    {
        isValid = root.hasVariableNode();
    }


    void updateFitness()
    {

version(simpleFitness)
{
            //in prima apporssimazione:
            fitness = 1.0 / rms;
}

version(complexFitness)
{
            // piu' complicato:
            // calcolo un indice di complessita':
            real simplicity = (maxNodes - nodesCount) / cast(real) maxNodes;
            // simplicity  = 1 : individuo semplice (corto, minimo numero di nodi)
            // simplicity  = 0 : individuo complesso (massimo numero di nodi);
            assert(simplicity >= 0 && simplicity <= 1);

            // la fitness deve essere una funzione che privilegia gli individui piu' semplici
            // quindi deve essere direttamente proporzionale alla semplicita' e inversamente all'errore

            fitness = simplicity / rms;
}

    }


/*
    ~this()
    {
        // non dovrebbe servire
        root = null;
    }
*/

    void save(char[] filename)
    {
        File f = new File(filename, FileMode.OutNew);
        save(f);
        f.close();
    }

    void save(File f)
    {
        updateNodesCount();

//        if(! isfinite(maxError) || isnan(maxError)) maxError = real.max;
//        if(! isfinite(maxError) || isnan(minError)) minError = real.max;

        if(! isfinite(totalError) || isnan(totalError)) totalError = real.max;
        if(! isfinite(rms) || isnan(rms)) rms = real.max;

        f.writef("%s %s %s ", /*maxError, minError, */ totalError, rms, nodesCount);

        root.save(f);
    }


    void load(char[] filename)
    {
        File f = new File(filename);

        load(f);

        f.close();
    }

    void load(File f)
    {
        int nodesCountMatch;
        f.readf(/*&maxError, &minError, */ &totalError, &rms, &nodesCountMatch);

        // forzo la rivalutazione dell'errore
        forceEvaluation;

        root = new Node;

        root.load(f);

        //nodesCount = -1;
        updateNodesCount();
        //isValid = -1;
        updateIsValid();
        //assert(nodesCount == nodesCountMatch);

    }

    void forceEvaluation()
    {
//        maxError = -real.max;
//        minError = real.max;

        // errorRange = new RealRangeDetector;
        errorRange.reset;

        totalError = -1;
        rms = real.nan;
    }

    int opCmp(Object other)
    {
        return cast(int) copysign ( 1, (cast(Individual) other).fitness - fitness );
    }




    Node root;

    // buffer di errore minimo e massimo. i valori coincidono con quelli indiciati dentro errors dai relativi indici qui sopra
//    real maxError = -real.max;
//    real minError = real.max;

    //RealRangeDetector errorRange;
    RangeDetector!(real) errorRange;

    // somma di tutti i (valori assoluti degli) errori su tutto il dataset
    // ocio! la evalTotalError viene fatta SOLO se totalError == -1;
    real totalError = -1;

    // root mean square, per conffrontarla con Paolo
    real rms;

    real fitness;

    int nodesCount = - 1;

    bool isValid;

//    int tournamentWins;
//    int birthGeneration;

    // RegressionData regressionData;

}



