#include <assert.h>
#include <time.h>
#include <stdlib.h>
#include <iostream>
#include <math.h>

using namespace std;

template <typename Key, typename Value>
struct NodeImpl{
  Key tree_key;
  Value payload;
  long heap_key;
  private: typedef NodeImpl<Key,Value>* Node;
  Node left,right;

  private: static long new_heap_key()
  {
    static bool need_init=true;
    if (need_init){
      srand(time(NULL));
      need_init = false;
    }
    return rand();
  }

  public: NodeImpl(Key const& k, Value const& v)
    :tree_key(k),payload(v),heap_key(new_heap_key()), left(NULL), right(NULL)
  {
  }


  // Simple checking function for binary tree
  public: static bool exists(Node treap, Key const& k)
  {
    if (!treap) return false;
    if (k == treap->tree_key) return true;
    return exists( (k<treap->tree_key)? treap->left : treap->right, k);
  }


  // Splits given treap by given k tree key.  Saves subtrees into l and r out params
  public: static void split(Node const& treap, Key const& k, Node & l, Node &r)
  {
    if (!treap){
      l = r = NULL;
    }
    else if (k < treap->tree_key) {
      split(treap->left, k, l, treap->left);
      r = treap;
    }
    else /* k > treap->tree_key */{
      split(treap->right, k, treap->right, r);
      l = treap;
    }
  }


  // Makes treap a root of a new tree with inserted key
  public: static void insert(Node & treap, Node new_node)
  {
    if (!treap) {
      treap = new_node;
      return;
    }
    if (treap->heap_key > new_node->heap_key){
      insert( ((new_node->tree_key < treap->tree_key)? treap->left : treap->right), new_node);
    }else{
      split(treap, new_node->tree_key, new_node->left, new_node->right);
      treap = new_node;
    }
  }

  // Calculate height
  public: static unsigned long height(Node const & treap)
  {
    if (!treap) return 0;
    unsigned long lh = height(treap->left), rh = height(treap->right);
    return  1+ ((lh<rh)? rh : lh);
  }
};

typedef NodeImpl<int,int> Node;

#ifndef STTREE
int main()
{
  Node * x = NULL;
  long k,v,i;
  while (cin >> k >> v){
    Node::insert(x, new Node(k,v));
    i++;
  }
  cout << "Height is " << Node::height(x) << " for RB it is " << (2*log(i))  ;
#ifdef SANITY_CHECK
  for (long i = 0; i<10000000; i++){
    if (i%2){
      assert(Node::exists(x,i));
    }else{
      assert(!Node::exists(x,i));
    }
  }
#endif
}
#else
#include <map>
int main()
{
  std::map<int,int> m;
  long k,v;
  while (cin >> k >> v){
    m.insert(std::pair<int,int>(k,v));
  }
  cout << "Height not supported :(\n";
}
#endif
