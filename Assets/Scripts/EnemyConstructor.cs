using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyConstructor : MonoBehaviour
{
    public Vector3 position;
    public bool faceDir;

    //public SpriteRenderer spriteRenderer;
    //public Animator animator;
    //public Rigidbody2D rigidbody2D;
    //public BoxCollider2D collider2D;
    //public ActivationScript activationScript;
}

public class WaddleDee : EnemyConstructor
{
    public WaddleDeeAIScript waddleDeeAi;
}

