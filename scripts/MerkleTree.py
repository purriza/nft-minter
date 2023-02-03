#!/usr/bin/python
import hashlib,sys
#from merkly.mtree import MerkleTree # https://github.com/olivmath/merkly
import merklyTree.merkly as merkly

# Take the leaves input (Should be in format ['a','b','c','d'])
inputString = sys.argv[1]
leavesString = inputString[1:len(inputString)-1]
leaves = leavesString.split(",")

# Create the Merkle Tree
mtree = merkly.MerkleTree(leaves)

# Save data on a file
f = open("merkle.tree", "w")

f.write("MERKLE ROOT \n")
f.write(mtree.root + "\n\n")

f.write("MERKLE PROOFS \n")
for i in range(len(mtree.leafs)):
    print(leaves[i])
    print(mtree.leafs[i])
    print(mtree.proof(leaves[i]))
    f.write("LEAF " + repr(i) + "\n")
    f.write(mtree.leafs[i])

    leafProof = mtree.proof(leaves[i])
    for p in leafProof:
        f.write(repr(p) + "\n")
f.close()

def getRoot():
    # Take the leaves input (Should be in format ['a','b','c','d'])
    inputString = sys.argv[1]
    leavesString = inputString[1:len(inputString)-1]
    print(inputString)
    leaves = leavesString.split(",")
    print(leaves)
    print(len(leaves))

    # Create the Merkle Tree
    mtree = MerkleTree(leaves)

    return mtree.root

def getProof(leaf):
    return mtree.proof(leaf)