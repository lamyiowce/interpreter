
// Some basic examples.
f :: Bool = true;
n :: Int = 423;
x :: Int = let f :: Int = 45 in f * 23;
funApply :: Test = fun (1+1) 1;
cons :: List Int = 1:2:3:4:[];
lambda :: Bool -> Int = \ (x :: Int -> Bool -> Int, y::Int) -> x y;
if1 :: Int = if true && false then 123 else let f :: Int = 45 in f + 23;
if2 :: Int = if true && 13 > y then 123 else 11;
someList :: List Int = [1,2+3,3*19,4];
listOfFunctions :: List Int -> Int = [\(r :: Int) -> 3*r, \(r :: Int) -> r+r];

// Cases example.
dziesiec :: Bool = case 10 of {
	10 -> true;
	_ -> false
};

cases :: Int = case x of { 
	(y :: Bool) -> 23; 
	12:[23] -> 11;
	x:(xs :: List Int) -> 1244;
	a:b:c:d:rest -> 124;
	p@x:xs -> x:p;
	s -> 12
};

cases2 :: Int = case x of {
	Some a -> 1;
	Nothing -> 0
};

// Exponential Fibonacci.
n :: Int = 100;
fibo :: Int -> Int = \(n :: Int) ->
	if n == 1 || n == 2 then 1 else fibo (n-1) + fibo (n-2);
alot :: Int = fibo n;

// Higher order function.
mapInt :: List Int -> (Int -> Int) -> List Int = 
	\(lst :: List Int, fun :: Int -> Int) -> case lst of {
		[] -> [];
		x:xs -> (fun x):(map xs fun)
};

// Double numbers in the list.
doubleTheList :: List Int -> List Int = 
	\(lst :: List Int) -> mapInt lst (\(x :: Int) -> x*2);

// Closure
f x :: Int -> Int -> Int = 
	let g :: Int -> Int = \(y :: Int) -> y+x in
		g;

// Syntactic sugar for sumOfTwo = \a -> \b -> ... 
sumOfTwo a b :: Int -> Int -> Int = a + b;

// Simple Maybe for Ints
data MaybeInt = Nothing | Some Int;

// Parametrized Maybe type
data Maybe a = Nothing | Some a;

// Recursive parametrized type
data Tree a = Empty | Node a Tree Tree;

// Custom parametrized list.
data MyList a = Empty | Nonempty a MyList;