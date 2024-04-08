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

    private float distanceToActivate = 10f;

    // Start is called before the first frame update
    void Awake()
    {
        spriteRenderer = GetComponent<SpriteRenderer>();
        animator = GetComponent<Animator>();
        boxCollider2D = GetComponent<BoxCollider2D>();
        waddleDeeAIScript = GetComponent<WaddleDeeAIScript>();

        kirby = GameObject.FindWithTag("Player");

        spriteRenderer.enabled = false;
        animator.enabled = false;
        boxCollider2D.enabled = false;
        waddleDeeAIScript.enabled = false;
    }

    // Update is called once per frame
    void Update()
    {
        if (Vector3.Distance(this.transform.position, kirby.transform.position) < distanceToActivate)
        {
            spriteRenderer.enabled = true;
            animator.enabled = true;
            gameObject.GetComponent<Rigidbody2D>().bodyType = RigidbodyType2D.Dynamic;
            boxCollider2D.enabled = true;
            waddleDeeAIScript.enabled = true;

            this.enabled = false;
        }
    }
}
