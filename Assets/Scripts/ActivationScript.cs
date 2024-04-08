using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class ActivationScript : MonoBehaviour
{
    private SpriteRenderer spriteRenderer;
    private Animator animator;
    private BoxCollider2D boxCollider2D;
    private WaddleDeeAIScript waddleDeeAIScript;

    private GameObject kirby;

    private readonly float distanceToActivate = 8f;

    // Start is called before the first frame update
    void Awake()
    {
        this.spriteRenderer = GetComponent<SpriteRenderer>();
        this.animator = GetComponent<Animator>();
        this.boxCollider2D = GetComponent<BoxCollider2D>();
        this.waddleDeeAIScript = GetComponent<WaddleDeeAIScript>();

        kirby = GameObject.FindWithTag("Player");

        this.spriteRenderer.enabled = false;
        this.animator.enabled = false;
        this.boxCollider2D.enabled = false;
        this.waddleDeeAIScript.enabled = false;
    }

    // Update is called once per frame
    void Update()
    {
        if (Vector3.Distance(this.transform.position, kirby.transform.position) < distanceToActivate)
        {
            this.spriteRenderer.enabled = true;
            this.animator.enabled = true;
            this.gameObject.GetComponent<Rigidbody2D>().bodyType = RigidbodyType2D.Dynamic;
            this.boxCollider2D.enabled = true;
            this.waddleDeeAIScript.enabled = true;

            this.enabled = false;
        }
    }
}
