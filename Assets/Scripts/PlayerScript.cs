using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerScript : MonoBehaviour
{
    public ControllerScript controller;
    private PlayerControls controls;
    public Animator animator;
    private Rigidbody2D kirbyBody;

    public float moveSpeed = 40f;
    private float horizontalMove = 0f;

    private Vector2 moveInput;
    private bool jumpInput = false;

    private bool hasBlinked = false;

    private float xVelocity = 0f;
    private float yVelocity = 0f;

    private void Awake()
    {
        controls = new PlayerControls();
        controls.Gameplay.Enable();
        kirbyBody = GetComponent<Rigidbody2D>();
        //Time.timeScale = 0.2f;

        //Move Input
        controls.Gameplay.Move.performed += ctx => moveInput = ctx.ReadValue<Vector2>();
        controls.Gameplay.Move.canceled += ctx => moveInput = Vector2.zero;

        //Jump Input
        controls.Gameplay.Jump.performed += ctx => jumpInput = true;
        controls.Gameplay.Jump.canceled += ctx => jumpInput = false;
    }

    // Update is called once per frame
    void Update()
    {
        xVelocity = Mathf.Abs(kirbyBody.velocity.x);
        yVelocity = Mathf.Abs(kirbyBody.velocity.y);

        horizontalMove = moveInput.x * moveSpeed;
        if (xVelocity > 0.3f)
        {
            animator.SetFloat("Speed", xVelocity);
        }
        else
        {
            animator.SetFloat("Speed", 0);
        }
        

        if (jumpInput)
        {
            animator.SetBool("IsGrounded", false);
        }
    }

    void FixedUpdate()
    {
        // Move our character
        controller.Move(horizontalMove * Time.fixedDeltaTime, jumpInput);

        if (hasBlinked)
        {
            animator.SetBool("IsBlinking", false);
            hasBlinked = false;
        }
    }

    public void IsGrounded()
    {
        animator.SetBool("IsGrounded", true);
        animator.SetBool("IsFalling", false);
    }

    public void IsFalling()
    {
        animator.SetBool("IsFalling", true);
        animator.SetBool("IsGrounded", false);
    }

    public void IsBlinking()
    {
        animator.SetBool("IsBlinking", true);
        hasBlinked = true;
    }
}
