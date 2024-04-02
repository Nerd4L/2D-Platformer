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
    public float jumpForce = 300f;                                              // Amount of force added when the player jumps.
    private float horizontalMove = 0f;

    private Vector2 moveInput;
    private bool jumpInput = false;
    [SerializeField] private bool dropDown = false;

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

        //DropDown Input
        controls.Gameplay.DropDown.performed += ctx => dropDown = true;
        controls.Gameplay.DropDown.canceled += ctx => dropDown = false;
    }

    // Update is called once per frame
    void Update()
    {
        xVelocity = Mathf.Abs(kirbyBody.velocity.x);
        yVelocity = Mathf.Abs(kirbyBody.velocity.y);

        horizontalMove = moveInput.x * moveSpeed;

        animator.SetFloat("Speed", xVelocity);
        if (xVelocity < 0.3f)
        {
            animator.SetFloat("Speed", 0);
        }        

        if (jumpInput)
        {
            animator.SetBool("IsGrounded", false);
        }

        //controller.DropDown(dropDown);
    }

    void FixedUpdate()
    {
        // Move our character
        controller.Move(horizontalMove * Time.fixedDeltaTime, jumpInput, jumpForce, dropDown);

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
        animator.SetBool("IsJumping", false);
    }

    public void IsBlinking()
    {
        animator.SetBool("IsBlinking", true);
        hasBlinked = true;
    }

    public void IsJumping()
    {
        animator.SetBool("IsJumping", true);
        animator.SetBool("IsFalling", false);
    }
}
